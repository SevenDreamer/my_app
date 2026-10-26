// HID 手柄模拟插件：围绕 android.bluetooth.BluetoothHidDevice（API 28+）。
// 输入报告格式与 lib/features/device_link/gamepad/gamepad_report.dart 一致：
// payload 9 字节（按钮 2 + hat 1 + 轴 4 + 扳机 2），reportId = 0x01。
package com.myapp.hid_gamepad

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHidDevice
import android.bluetooth.BluetoothHidDeviceAppQosSettings
import android.bluetooth.BluetoothHidDeviceAppSdpSettings
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

class HidGamepadPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, ActivityAware {
    private lateinit var context: Context
    private var activity: Activity? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var events: EventChannel.EventSink? = null

    private var hid: BluetoothHidDevice? = null
    private var host: BluetoothDevice? = null
    private var callback: BluetoothHidDevice.Callback? = null
    private var appName: String = "my_app Gamepad"

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "my_app/hid_gamepad")
            .also { it.setMethodCallHandler(this) }
        eventChannel = EventChannel(binding.binaryMessenger, "my_app/hid_gamepad/events")
            .also { it.setStreamHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        unregister()
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.events = events
    }

    override fun onCancel(arguments: Any?) {
        this.events = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                appName = call.argument<String>("name") ?: appName
                start(result)
            }
            "sendReport" -> sendReport(call, result)
            "stop" -> {
                unregister()
                emit("idle")
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun emit(state: String) {
        Handler(Looper.getMainLooper()).post { events?.success(state) }
    }

    private fun start(result: MethodChannel.Result) {
        unregister() // 重复启动/重试前清理上一次注册
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            result.error("api_level", "HID 手柄模拟需要 Android 9+，本机 ${Build.VERSION.RELEASE}", null)
            return
        }
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = manager?.adapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("bluetooth_off", "蓝牙未开启或设备无蓝牙", null)
            return
        }
        val proxyRequested = adapter.getProfileProxy(context, object : BluetoothProfile.ServiceListener {
            override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                @Suppress("UNCHECKED_CAST")
                hid = proxy as BluetoothHidDevice
                if (!registerApp(result)) {
                    result.error("register_failed", "HID 应用注册失败（可能已被占用或不被 ROM 支持）", null)
                }
            }

            override fun onServiceDisconnected(profile: Int) {
                hid = null
                emit("disconnected")
            }
        }, BluetoothProfile.HID_DEVICE)
        if (!proxyRequested) {
            result.error("hid_unavailable", "本机不支持 HID Device 角色（BluetoothHidDevice）", null)
        }
    }

    private fun registerApp(result: MethodChannel.Result): Boolean {
        val hidDevice = hid ?: return false
        val sdp = BluetoothHidDeviceAppSdpSettings(
            appName,
            "my_app Virtual Gamepad",
            "my_app",
            BluetoothHidDevice.SUBCLASS2_GAMEPAD,
            descriptor(),
        )
        // 输入 QoS：尽力而为（游戏输入容忍少量丢包，换低延迟）
        val qosIn = BluetoothHidDeviceAppQosSettings(
            BluetoothHidDeviceAppQosSettings.SERVICE_BEST_EFFORT,
            800, 9, 800, 9, 12,
        )
        // 输出 QoS：手柄侧暂无输出（震动二期），声明无流量
        val qosOut = BluetoothHidDeviceAppQosSettings(
            BluetoothHidDeviceAppQosSettings.SERVICE_NO_TRAFFIC,
            0, 0, 0, 0, 0,
        )
        val cb = object : BluetoothHidDevice.Callback() {
            override fun onAppStatusChanged(device: BluetoothDevice?, connected: Boolean) {
                // 注意：注册成功也会回调这里（device 可能为 null 的虚拟插拔），
                // 不能当真实连接——只有带真实 device 的插拔才改状态
                if (connected && device != null) {
                    host = device
                    emit("connected")
                } else if (!connected) {
                    host = null
                    emit("advertising")
                }
            }

            override fun onConnectionStateChanged(device: BluetoothDevice?, state: Int) {
                when (state) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        host = device
                        emit("connected")
                    }
                    BluetoothProfile.STATE_DISCONNECTED -> {
                        host = null
                        emit("disconnected")
                    }
                }
            }

            override fun onGetReport(device: BluetoothDevice?, type: Byte, id: Byte, bufferSize: Int) {
                // 主机枚举时会来查询输入报告；不回会被判无响应。
                // 回一帧全中立状态（hat=8 居中、轴=128、扳机=0）。
                hid?.replyReport(device, type, id, neutralReport())
            }
        }
        callback = cb
        val executor = Executor { runnable -> Handler(Looper.getMainLooper()).post(runnable) }
        val ok = hidDevice.registerApp(sdp, qosIn, qosOut, executor, cb)
        if (ok) {
            emit("advertising")
            result.success(null)
            requestDiscoverable()
        }
        return ok
    }

    // 让本机「可被发现」——否则主机端扫描看不到本机（Android 蓝牙默认不可发现）
    private fun requestDiscoverable() {
        val act = activity ?: return
        try {
            act.startActivity(
                Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE)
                    .putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, 300),
            )
        } catch (_: Exception) {
            // 部分 ROM 拦截该 Intent：忽略，由用户在系统蓝牙设置手动开「可被发现」
        }
    }

    private fun sendReport(call: MethodCall, result: MethodChannel.Result) {
        val report = call.argument<ByteArray>("report")
        val hidDevice = hid
        val target = host
        if (report == null || report.size != REPORT_LENGTH) {
            result.error("bad_report", "报告应为 $REPORT_LENGTH 字节", null)
            return
        }
        if (hidDevice == null || target == null) {
            result.error("no_host", "尚未连接主机（先在主机端配对本机）", null)
            return
        }
        val ok = hidDevice.sendReport(target, report[0].toInt(), report.copyOfRange(1, report.size))
        result.success(ok)
    }

    private fun unregister() {
        try {
            hid?.unregisterApp()
        } catch (_: Exception) {
        }
        callback = null
        host = null
    }

    companion object {
        private const val REPORT_LENGTH = 10

        private fun neutralReport(): ByteArray = byteArrayOf(
            0x00, 0x00, // 按钮 16 位全松
            0x08,       // hat = 8（居中）
            0x7F.toByte(), 0x7F.toByte(), 0x7F.toByte(), 0x7F.toByte(), // 轴 128 居中
            0x00, 0x00, // 扳机 0
        )

        private fun bytes(vararg values: Int) =
            ByteArray(values.size) { values[it].toByte() }

        // HID 报告描述符：Game Pad，Report ID 1
        // [1-2] 按钮 16 位 → [3] hat(4bit)+补位 → [4-7] X/Y/Z/Rz → [8-9] 扳机按钮 11/12
        private fun descriptor(): ByteArray = bytes(
            0x05, 0x01,        // Usage Page (Generic Desktop)
            0x09, 0x05,        // Usage (Game Pad)
            0xA1, 0x01,        // Collection (Application)
            0x85, 0x01,        //   Report ID (1)
            0x05, 0x09,        //   Usage Page (Button)
            0x19, 0x01,        //   Usage Minimum (1)
            0x29, 0x0A,        //   Usage Maximum (10)
            0x15, 0x00,        //   Logical Minimum (0)
            0x25, 0x01,        //   Logical Maximum (1)
            0x75, 0x01,        //   Report Size (1)
            0x95, 0x0A,        //   Report Count (10)
            0x81, 0x02,        //   Input (Data,Var,Abs)
            0x75, 0x01,        //   Report Size (1)
            0x95, 0x06,        //   Report Count (6)
            0x81, 0x03,        //   Input (Const) —— 按钮补齐 16 位
            0x05, 0x01,        //   Usage Page (Generic Desktop)
            0x09, 0x39,        //   Usage (Hat Switch)
            0x15, 0x00,        //   Logical Minimum (0)
            0x25, 0x07,        //   Logical Maximum (7)
            0x35, 0x00,        //   Physical Minimum (0)
            0x46, 0x3B, 0x01,  //   Physical Maximum (315)
            0x75, 0x04,        //   Report Size (4)
            0x95, 0x01,        //   Report Count (1)
            0x81, 0x42,        //   Input (Data,Var,Abs,Null) —— 8/15 = 居中
            0x75, 0x04,        //   Report Size (4)
            0x95, 0x01,        //   Report Count (1)
            0x81, 0x03,        //   Input (Const) —— hat 占满一字节
            0x09, 0x30,        //   Usage (X) → lx
            0x09, 0x31,        //   Usage (Y) → ly
            0x09, 0x32,        //   Usage (Z) → rx
            0x09, 0x35,        //   Usage (Rz) → ry
            0x15, 0x00,        //   Logical Minimum (0)
            0x26, 0xFF, 0x00,  //   Logical Maximum (255)
            0x75, 0x08,        //   Report Size (8)
            0x95, 0x04,        //   Report Count (4)
            0x81, 0x02,        //   Input (Data,Var,Abs)
            0x05, 0x09,        //   Usage Page (Button)
            0x19, 0x0B,        //   Usage Minimum (11) → L2
            0x29, 0x0C,        //   Usage Maximum (12) → R2
            0x15, 0x00,        //   Logical Minimum (0)
            0x26, 0xFF, 0x00,  //   Logical Maximum (255)
            0x75, 0x08,        //   Report Size (8)
            0x95, 0x02,        //   Report Count (2)
            0x81, 0x02,        //   Input (Data,Var,Abs)
            0xC0,              // End Collection
        )
    }
}

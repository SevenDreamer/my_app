#!/usr/bin/env python
# R2 上传小工具：S3 API（SigV4 签名）直传。
# 为什么不用 wrangler：r2 object put 默认本地模式（写进本机 Miniflare），
# --remote 又要求 CLOUDFLARE_API_TOKEN 具备桶级权限；S3 密钥走标准协议最稳。
# 用法：python tool/r2_upload.py <bucket> <key> <本地文件> [content-type]
# 依赖环境变量：S3_ACCESS_KEY_ID / S3_SECRET_ACCESS_KEY（tool/r2.env，release.sh 自动加载）
import datetime
import hashlib
import hmac
import os
import sys
import urllib.request

ENDPOINT = '0a5e8b01a70285a19456d23671233de8.r2.cloudflarestorage.com'


def main() -> int:
    if len(sys.argv) < 4:
        print('用法：python tool/r2_upload.py <bucket> <key> <本地文件> [content-type]',
              file=sys.stderr)
        return 1
    bucket, key, path = sys.argv[1], sys.argv[2], sys.argv[3]
    ctype = sys.argv[4] if len(sys.argv) > 4 else 'application/octet-stream'
    akid = os.environ['S3_ACCESS_KEY_ID']
    secret = os.environ['S3_SECRET_ACCESS_KEY']

    with open(path, 'rb') as f:
        data = f.read()
    payload_hash = hashlib.sha256(data).hexdigest()

    now = datetime.datetime.now(datetime.timezone.utc)
    amzdate = now.strftime('%Y%m%dT%H%M%SZ')
    datestamp = now.strftime('%Y%m%d')
    canonical_uri = '/' + bucket + '/' + key
    canonical_headers = (f'host:{ENDPOINT}\n'
                         f'x-amz-content-sha256:{payload_hash}\n'
                         f'x-amz-date:{amzdate}\n')
    signed_headers = 'host;x-amz-content-sha256;x-amz-date'
    canonical_request = (f'PUT\n{canonical_uri}\n\n{canonical_headers}\n'
                         f'{signed_headers}\n{payload_hash}')
    scope = f'{datestamp}/auto/s3/aws4_request'
    string_to_sign = ('AWS4-HMAC-SHA256\n' + amzdate + '\n' + scope + '\n'
                      + hashlib.sha256(canonical_request.encode()).hexdigest())

    def _hmac(k: bytes, m: str) -> bytes:
        return hmac.new(k, m.encode(), hashlib.sha256).digest()

    k = _hmac(_hmac(_hmac(_hmac(f'AWS4{secret}'.encode(), datestamp), 'auto'),
                    's3'), 'aws4_request')
    signature = hmac.new(k, string_to_sign.encode(), hashlib.sha256).hexdigest()

    req = urllib.request.Request(
        f'https://{ENDPOINT}{canonical_uri}', data=data, method='PUT',
        headers={
            'Host': ENDPOINT,
            'Content-Type': ctype,
            'x-amz-content-sha256': payload_hash,
            'x-amz-date': amzdate,
            'Authorization': (f'AWS4-HMAC-SHA256 Credential={akid}/{scope}, '
                              f'SignedHeaders={signed_headers}, '
                              f'Signature={signature}'),
        })
    with urllib.request.urlopen(req, timeout=300) as resp:
        print(f'已上传：{key}（{len(data)} 字节，HTTP {resp.status}）')
    return 0


if __name__ == '__main__':
    sys.exit(main())

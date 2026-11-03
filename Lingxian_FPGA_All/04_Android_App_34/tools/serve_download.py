# -*- coding: utf-8 -*-
"""Local, read-only APK/preview download endpoint. Serves Android/dist only."""
from pathlib import Path
from http.server import ThreadingHTTPServer,BaseHTTPRequestHandler
from urllib.parse import urlsplit,unquote
import argparse,mimetypes
root=Path(__file__).resolve().parents[1]/'dist'
landing='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="theme-color" content="#f5f4ef"><title>灵弦 · 安卓下载</title><style>body{font:16px/1.8 sans-serif;color:#25382c;background:#f5f4ef;max-width:460px;padding:36px 24px;margin:auto}small{letter-spacing:3px;color:#71816b}h1{font-size:32px}a{display:block;text-decoration:none;padding:14px 18px;border-radius:12px;margin:14px 0;background:#3b624b;color:white;text-align:center}.secondary{background:white;color:#3b624b;border:1px solid #dfe6d8}p{font-size:14px;color:#6f7b68}.note{padding:18px;border:1px solid #dfe6d8;border-radius:14px}</style><small>LINGXIAN / ANDROID</small><h1>灵弦练习室</h1><p>安装后离线打开，内置三首曲谱。无需Mac、微信小程序注册或浏览器蓝牙支持。</p><a href="/app.apk" download="Lingxian-Android.apk">下载安卓 APK · 约 38 KB</a><p>安卓8.0及以上。若系统询问安装来源，请允许这次本地安装；连接乐器时再允许蓝牙权限。</p><a class="secondary" href="/quick-open.html">先免安装预览</a><div class="note"><strong>蓝牙模块还没到手？</strong><p>打开App → 设备 → 先预览，不连接硬件。预览始终明确标注，不会向开发板写数据。</p></div><p>网页本地预览不连接真实BLE；真实连接优先使用上面的APK。下载服务由你的电脑提供，手机和电脑需处于同一局域网。</p></html>'''
class Handler(BaseHTTPRequestHandler):
 def do_GET(self):
  path=unquote(urlsplit(self.path).path)
  if path=='/':
   data=landing.encode('utf-8');self.send_response(200);self.send_header('Content-Type','text/html; charset=utf-8');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data);return
  if path=='/app.apk':p=root/'Lingxian-Android.apk';content='application/vnd.android.package-archive'
  else:
   p=(root/path.lstrip('/')).resolve()
   if root.resolve() not in p.parents or not p.is_file():self.send_error(404);return
   content=mimetypes.guess_type(str(p))[0] or 'application/octet-stream'
  if not p.is_file():self.send_error(404);return
  data=p.read_bytes();self.send_response(200);self.send_header('Content-Type',content)
  if path=='/app.apk':self.send_header('Content-Disposition','attachment; filename="Lingxian-Android.apk"')
  self.send_header('Content-Length',str(len(data)));self.send_header('Cache-Control','no-cache');self.end_headers();self.wfile.write(data)
 def log_message(self,fmt,*args):print(self.address_string(),fmt%args,flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--bind',default='0.0.0.0');p.add_argument('--port',type=int,default=8765);a=p.parse_args()
 server=ThreadingHTTPServer((a.bind,a.port),Handler);print('Lingxian APK download server',a.bind,a.port,'root',root,flush=True);server.serve_forever()

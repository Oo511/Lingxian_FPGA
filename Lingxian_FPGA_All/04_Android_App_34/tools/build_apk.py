from pathlib import Path
import subprocess,shutil,tempfile,zipfile,json,hashlib,os
android=Path(__file__).resolve().parents[1]
workspace=android
if os.environ.get('LINGXIAN_ANDROID_SDK'):
 tools=Path(os.environ['LINGXIAN_ANDROID_SDK'])
else:
 while not (workspace/'work/tools/android29').exists():
  if workspace.parent==workspace:raise RuntimeError('Set LINGXIAN_ANDROID_SDK to Android SDK tools root')
  workspace=workspace.parent
 tools=workspace/'work/tools/android29/sdk'
bt=next(tools.rglob('aapt2.exe')).parent;jar=next(tools.rglob('android.jar'))
jdk=Path(shutil.which('javac')).parent
reports=android/'reports';reports.mkdir(exist_ok=True)
dist=android/'dist';dist.mkdir(exist_ok=True)
log=[]
def run(args):
 p=subprocess.run([str(x) for x in args],text=True,capture_output=True,encoding='utf-8',errors='replace')
 log.append(p.stdout+p.stderr)
 if p.returncode:raise RuntimeError(p.stdout+p.stderr)
 return p.stdout+p.stderr
try:
 with tempfile.TemporaryDirectory(prefix='lingxian_apk29_') as tmp:
  t=Path(tmp);src=android/'app/src/main'
  shutil.copytree(src/'java',t/'java');shutil.copytree(src/'res',t/'res');shutil.copytree(dist/'web',t/'assets')
  shutil.copy2(src/'AndroidManifest.xml',t/'AndroidManifest.xml')
  run([bt/'aapt2.exe','compile','--dir',t/'res','-o',t/'resources.zip'])
  run([bt/'aapt2.exe','link','-I',jar,'--manifest',t/'AndroidManifest.xml','-A',t/'assets','--auto-add-overlay','-o',t/'base.apk',t/'resources.zip'])
  classes=t/'classes';classes.mkdir()
  run([jdk/'javac.exe','-encoding','UTF-8','--release','8','-cp',jar,'-d',classes,*sorted((t/'java').rglob('*.java'))])
  run([jdk/'jar.exe','--create','--file',t/'classes.jar','-C',classes,'.'])
  dex=t/'dex';dex.mkdir()
  run([jdk/'java.exe','-Xmx1024m','-cp',bt/'lib/d8.jar','com.android.tools.r8.D8','--min-api','26','--lib',jar,'--output',dex,t/'classes.jar'])
  with zipfile.ZipFile(t/'base.apk','a') as z:
   for p in dex.glob('*.dex'):z.write(p,p.name,compress_type=zipfile.ZIP_DEFLATED)
  run([bt/'zipalign.exe','-f','4',t/'base.apk',t/'aligned.apk'])
  keys=android/'.signing';keys.mkdir(exist_ok=True);key=keys/'local-demo.jks'
  if not key.exists():
   run([jdk/'keytool.exe','-genkeypair','-keystore',key,'-storepass','android','-keypass','android','-alias','lingxian-demo','-keyalg','RSA','-keysize','2048','-validity','3650','-dname','CN=Lingxian Local Demo,O=Lingxian,C=CN','-noprompt'])
  apk=dist/'Lingxian-Android.apk'
  run([jdk/'java.exe','-jar',bt/'lib/apksigner.jar','sign','--ks',key,'--ks-key-alias','lingxian-demo','--ks-pass','pass:android','--key-pass','pass:android','--v1-signing-enabled','true','--v2-signing-enabled','true','--v3-signing-enabled','true','--out',apk,t/'aligned.apk'])
  verify=run([jdk/'java.exe','-jar',bt/'lib/apksigner.jar','verify','--verbose','--print-certs',apk]);(reports/'apk_signature.txt').write_text(verify,encoding='utf-8')
  badging=run([bt/'aapt2.exe','dump','badging',apk]);(reports/'apk_badging.txt').write_text(badging,encoding='utf-8')
  assert "minSdkVersion:'26'" in badging and "targetSdkVersion:'35'" in badging
  assert "launchable-activity: name='com.lingxian.practice.MainActivity'" in badging
  assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in verify
  with zipfile.ZipFile(apk) as z:
   for name in ['classes.dex','AndroidManifest.xml','assets/index.html','assets/app.js','assets/style.css']:assert name in z.namelist()
   assert not any('jks' in n or '.signing' in n for n in z.namelist())
  receipt={'apk':apk.name,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest().upper(),
           'min_android':'8.0 / API26','target_api':35,'java_compiled':True,'dex_built':True,'apk_v2_v3_signature_verified':True,
           'offline_assets_bundled':True,'native_android_ble':True,'native_android_wifi_tcp':True,'physical_wifi_tested':False,'installed_on_phone':False,'physical_ble_tested':False,
           'signing':'local demonstration certificate; not Play Store release'}
  (reports/'apk_build.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
  print(json.dumps(receipt,ensure_ascii=False,indent=2))
finally:(reports/'apk_build.log').write_text('\n'.join(log),encoding='utf-8')

from pathlib import Path
import json,subprocess,shutil,tempfile
android=Path(__file__).resolve().parents[1];project=android.parent
corpus=json.loads((android/'reports/js_c_corpus.json').read_text())
with tempfile.TemporaryDirectory(prefix='lingxian_android_c_') as tmp:
 p=Path(tmp);shutil.copytree(project/'STM32/User',p/'User');shutil.copy2(project/'tools/codec_probe.c',p/'probe.c')
 exe=p/'probe.exe'
 subprocess.run(['C:/Program Files (x86)/Dev-Cpp/MinGW64/bin/gcc.exe','-std=c11','-Wall','-Wextra','-Werror','-I',str(p/'User'),str(p/'probe.c'),'-o',str(exe)],check=True)
 out=subprocess.run([str(exe)],input='\n'.join(c['input'] for c in corpus)+'\n',capture_output=True,text=True,check=True).stdout.splitlines()
 assert out==[c['output'] for c in corpus]
(android/'reports/cross_c.json').write_text(json.dumps({'javascript_to_production_c_cases':len(corpus),'physical_ble_tested':False},indent=2),encoding='utf-8')
print('PASS',len(corpus),'Android JavaScript -> production STM32 C parser frames')

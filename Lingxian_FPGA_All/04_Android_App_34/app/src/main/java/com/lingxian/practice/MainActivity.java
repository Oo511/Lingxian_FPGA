package com.lingxian.practice;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.*;
import android.bluetooth.le.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.location.LocationManager;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import java.util.concurrent.atomic.AtomicInteger;
import android.os.*;
import android.provider.Settings;
import android.util.Base64;
import android.view.View;
import android.webkit.*;
import android.widget.FrameLayout;
import org.json.JSONObject;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class MainActivity extends Activity {
    private static final UUID SERVICE=UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dcca9e");
    private static final UUID WRITE=UUID.fromString("6e400002-b5a3-f393-e0a9-e50e24dcca9e");
    private static final UUID NOTIFY=UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dcca9e");
    private static final UUID CCC=UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");
    private static final int PERMISSION_REQUEST=29,FILE_REQUEST=30,ENABLE_BT_REQUEST=31;
    private final Handler ui=new Handler(Looper.getMainLooper());
    private final ExecutorService network=Executors.newSingleThreadExecutor();
    private final ExecutorService wifiIo=Executors.newSingleThreadExecutor();
    private final AtomicInteger wifiEpoch=new AtomicInteger();
    private volatile Socket wifiSocket;
    private final Map<String,BluetoothDevice> found=new LinkedHashMap<>();
    private BluetoothAdapter adapter;private BluetoothLeScanner scanner;private BluetoothGatt gatt;
    private BluetoothGattCharacteristic writeCharacteristic;
    private int connectId,writeId;private String deviceName="Lingxian-29";private boolean pendingScan,scanning;
    private Runnable connectTimeout,writeTimeout;
    private WebView web;private ValueCallback<android.net.Uri[]> fileCallback;

    @Override public void onCreate(Bundle state){
        super.onCreate(state);
        getWindow().setStatusBarColor(0xfff5f4ef);getWindow().setNavigationBarColor(0xfffafbf8);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR|View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
        FrameLayout root=new FrameLayout(this);root.setBackgroundColor(0xfff5f4ef);root.setFitsSystemWindows(Build.VERSION.SDK_INT<30);
        if(Build.VERSION.SDK_INT>=30)root.setOnApplyWindowInsetsListener((v,insets)->{
            android.graphics.Insets i=insets.getInsets(android.view.WindowInsets.Type.systemBars()|android.view.WindowInsets.Type.displayCutout());
            v.setPadding(i.left,i.top,i.right,i.bottom);return android.view.WindowInsets.CONSUMED;
        });
        web=new WebView(this);root.addView(web,new FrameLayout.LayoutParams(-1,-1));setContentView(root);
        web.getSettings().setJavaScriptEnabled(true);web.getSettings().setDomStorageEnabled(true);
        web.getSettings().setAllowFileAccess(true);web.getSettings().setAllowContentAccess(true);
        web.getSettings().setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        web.addJavascriptInterface(new Bridge(),"AndroidBridge");
        web.setWebViewClient(new WebViewClient(){
            @Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest r){
                return !"file".equals(r.getUrl().getScheme());
            }
        });
        web.setWebChromeClient(new WebChromeClient(){
            @Override public boolean onShowFileChooser(WebView v,ValueCallback<android.net.Uri[]> callback,FileChooserParams params){
                if(fileCallback!=null)fileCallback.onReceiveValue(null);fileCallback=callback;
                Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT);i.addCategory(Intent.CATEGORY_OPENABLE);i.setType("application/json");
                i.putExtra(Intent.EXTRA_MIME_TYPES,new String[]{"application/json","text/plain","application/octet-stream"});
                try{startActivityForResult(i,FILE_REQUEST);}catch(ActivityNotFoundException e){fileCallback.onReceiveValue(null);fileCallback=null;}
                return true;
            }
        });
        BluetoothManager manager=(BluetoothManager)getSystemService(BLUETOOTH_SERVICE);adapter=manager==null?null:manager.getAdapter();
        web.loadUrl("file:///android_asset/index.html");
    }
    private JSONObject event(String type){JSONObject o=new JSONObject();put(o,"type",type);return o;}
    private void put(JSONObject o,String key,Object value){try{o.put(key,value);}catch(Exception ignored){}}
    private void emit(JSONObject o){ui.post(()->{if(web!=null)web.evaluateJavascript("window.LingxianNative&&window.LingxianNative.receive("+o.toString()+");",null);});}
    private void error(String message){JSONObject e=event("error");put(e,"message",message);emit(e);}
    private void replyError(int id,String message){JSONObject e=event("result");put(e,"id",id);put(e,"error",message);emit(e);}
    private boolean permitted(){
        if(Build.VERSION.SDK_INT>=31)return checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN)==PackageManager.PERMISSION_GRANTED&&checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)==PackageManager.PERMISSION_GRANTED;
        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED;
    }
    private void requestScan(){
        if(adapter==null){error("此手机没有可用的BLE蓝牙，仍可使用预览。");return;}
        if(!permitted()){
            pendingScan=true;
            requestPermissions(Build.VERSION.SDK_INT>=31?new String[]{Manifest.permission.BLUETOOTH_SCAN,Manifest.permission.BLUETOOTH_CONNECT}:new String[]{Manifest.permission.ACCESS_FINE_LOCATION},PERMISSION_REQUEST);return;
        }
        try{
            if(!adapter.isEnabled()){pendingScan=true;startActivityForResult(new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),ENABLE_BT_REQUEST);return;}
            if(Build.VERSION.SDK_INT<31){
                LocationManager lm=(LocationManager)getSystemService(LOCATION_SERVICE);
                boolean location=Build.VERSION.SDK_INT>=28?lm!=null&&lm.isLocationEnabled():Settings.Secure.getInt(getContentResolver(),Settings.Secure.LOCATION_MODE,0)!=0;
                if(!location){error("旧安卓系统扫描BLE还需要打开系统定位开关；打开后再点搜索。");return;}
            }
            stopScan();found.clear();scanner=adapter.getBluetoothLeScanner();if(scanner==null){error("蓝牙尚未就绪，请重试。");return;}
            scanner.startScan(Collections.singletonList(new ScanFilter.Builder().setServiceUuid(new ParcelUuid(SERVICE)).build()),new ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),scanCallback);
            scanning=true;JSONObject e=event("scanning");put(e,"active",true);emit(e);ui.postDelayed(this::stopScan,12000);
        }catch(SecurityException e){error("蓝牙权限未开启，请允许附近设备权限后重试。");}
        catch(Exception e){error("无法开始扫描："+e.getMessage());}
    }
    private final ScanCallback scanCallback=new ScanCallback(){
        @Override public void onScanResult(int type,ScanResult result){ui.post(()->{
            try{BluetoothDevice d=result.getDevice();String address=d.getAddress();found.put(address,d);
                String name=result.getScanRecord()!=null?result.getScanRecord().getDeviceName():null;if(name==null)name=d.getName();
                JSONObject e=event("device");put(e,"address",address);put(e,"name",name==null?"Lingxian BLE":name);put(e,"rssi",result.getRssi());emit(e);
            }catch(SecurityException ignored){}
        });}
        @Override public void onScanFailed(int code){ui.post(()->{stopScan();error("蓝牙扫描失败（"+code+"），请稍后重新搜索。");});}
    };
    private void stopScan(){
        if(!scanning)return;scanning=false;
        try{if(scanner!=null)scanner.stopScan(scanCallback);}catch(SecurityException ignored){}
        JSONObject e=event("scanning");put(e,"active",false);emit(e);
    }
    private void connect(int id,String address){
        if("wifi".equals(address)){connectWifi(id);return;}
        if(!permitted()){replyError(id,"请先搜索设备并允许蓝牙权限。");return;}
        BluetoothDevice d=found.get(address);if(d==null){replyError(id,"请从搜索结果中选择设备。");return;}
        stopScan();closeGatt(false);connectId=id;
        try{
            deviceName=d.getName()==null?"Lingxian-29":d.getName();
            gatt=d.connectGatt(this,false,gattCallback,BluetoothDevice.TRANSPORT_LE);
            if(gatt==null){connectionFailed("无法创建蓝牙连接");return;}
            connectTimeout=()->connectionFailed("连接超时，请确认模块通电且未被其他手机连接。");ui.postDelayed(connectTimeout,9000);
        }catch(Exception e){connectionFailed("连接失败："+e.getMessage());}
    }
    private void connectionFailed(String message){if(connectId!=0){replyError(connectId,message);connectId=0;}else error(message);closeGatt(true);}
    private void closeGatt(boolean notify){
        if(connectTimeout!=null)ui.removeCallbacks(connectTimeout);if(writeTimeout!=null)ui.removeCallbacks(writeTimeout);
        if(writeId!=0){replyError(writeId,"蓝牙连接已关闭");writeId=0;}
        BluetoothGatt old=gatt;gatt=null;writeCharacteristic=null;
        if(old!=null){try{old.disconnect();old.close();}catch(Exception ignored){}}
        if(connectId!=0){replyError(connectId,"蓝牙连接已关闭");connectId=0;}
        if(notify)emit(event("disconnected"));
    }
    private final BluetoothGattCallback gattCallback=new BluetoothGattCallback(){
        @Override public void onConnectionStateChange(BluetoothGatt g,int status,int newState){ui.post(()->{
            if(g!=gatt)return;
            if(status==BluetoothGatt.GATT_SUCCESS&&newState==BluetoothProfile.STATE_CONNECTED){
                try{if(!g.discoverServices())connectionFailed("无法发现蓝牙服务");}catch(SecurityException e){connectionFailed("蓝牙权限不可用");}
            }else connectionFailed("蓝牙连接已断开（"+status+"）");
        });}
        @Override public void onServicesDiscovered(BluetoothGatt g,int status){ui.post(()->{
            if(g!=gatt)return;
            if(status!=BluetoothGatt.GATT_SUCCESS){connectionFailed("蓝牙服务发现失败");return;}
            BluetoothGattService service=g.getService(SERVICE);BluetoothGattCharacteristic n=service==null?null:service.getCharacteristic(NOTIFY);
            writeCharacteristic=service==null?null:service.getCharacteristic(WRITE);
            if(n==null||writeCharacteristic==null||(writeCharacteristic.getProperties()&BluetoothGattCharacteristic.PROPERTY_WRITE)==0){connectionFailed("模块没有配套的灵弦BLE服务，请刷入ESP32桥接程序。");return;}
            BluetoothGattDescriptor ccc=n.getDescriptor(CCC);
            try{
                if(ccc==null||!g.setCharacteristicNotification(n,true)){connectionFailed("模块不支持通知");return;}
                ccc.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
                if(!g.writeDescriptor(ccc))connectionFailed("启用通知失败");
            }catch(SecurityException e){connectionFailed("蓝牙权限不可用");}
        });}
        @Override public void onDescriptorWrite(BluetoothGatt g,BluetoothGattDescriptor descriptor,int status){ui.post(()->{
            if(g!=gatt||!CCC.equals(descriptor.getUuid()))return;
            if(status!=BluetoothGatt.GATT_SUCCESS){connectionFailed("模块拒绝启用通知");return;}
            if(connectTimeout!=null)ui.removeCallbacks(connectTimeout);
            JSONObject e=event("connected");put(e,"id",connectId);put(e,"name",deviceName);connectId=0;emit(e);
        });}
        @Override public void onCharacteristicWrite(BluetoothGatt g,BluetoothGattCharacteristic c,int status){ui.post(()->{
            if(g!=gatt||!WRITE.equals(c.getUuid())||writeId==0)return;
            if(writeTimeout!=null)ui.removeCallbacks(writeTimeout);
            int id=writeId;writeId=0;
            if(status!=BluetoothGatt.GATT_SUCCESS)replyError(id,"蓝牙写入失败（"+status+"）");
            else{JSONObject e=event("written");put(e,"id",id);emit(e);}
        });}
        @Override public void onCharacteristicChanged(BluetoothGatt g,BluetoothGattCharacteristic c){received(g,c,c.getValue());}
        @Override public void onCharacteristicChanged(BluetoothGatt g,BluetoothGattCharacteristic c,byte[] value){received(g,c,value);}
    };
    private void received(BluetoothGatt g,BluetoothGattCharacteristic c,byte[] bytes){
        if(!NOTIFY.equals(c.getUuid())||bytes==null)return;final byte[] copy=bytes.clone();
        ui.post(()->{if(g!=gatt)return;JSONObject e=event("data");put(e,"data",Base64.encodeToString(copy,Base64.NO_WRAP));emit(e);});
    }
    private void write(int id,String encoded){
        if(wifiSocket!=null){writeWifi(id,encoded);return;}
        if(gatt==null||writeCharacteristic==null){replyError(id,"蓝牙未连接");return;}
        if(writeId!=0){replyError(id,"蓝牙正在发送上一片数据");return;}
        try{
            byte[] bytes=Base64.decode(encoded,Base64.DEFAULT);if(bytes.length<1||bytes.length>20){replyError(id,"蓝牙分片长度不正确");return;}
            writeId=id;writeCharacteristic.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT);writeCharacteristic.setValue(bytes);
            if(!gatt.writeCharacteristic(writeCharacteristic)){writeId=0;replyError(id,"蓝牙写入未开始，请重试");return;}
            writeTimeout=()->{if(writeId==id){writeId=0;replyError(id,"蓝牙写入超时");closeGatt(true);}};ui.postDelayed(writeTimeout,5000);
        }catch(Exception e){writeId=0;replyError(id,"蓝牙写入失败："+e.getMessage());}
    }
    private void closeWifi(boolean notify){
        wifiEpoch.incrementAndGet();Socket old=wifiSocket;wifiSocket=null;
        if(old!=null)try{old.close();}catch(IOException ignored){}
        if(notify)emit(event("disconnected"));
    }
    private void connectWifi(int id){
        stopScan();closeGatt(false);closeWifi(false);final int epoch=wifiEpoch.get();
        wifiIo.execute(()->{
            Socket candidate=null;
            try{
                ConnectivityManager cm=(ConnectivityManager)getSystemService(CONNECTIVITY_SERVICE);
                Network wlan=null;
                if(cm!=null)for(Network n:cm.getAllNetworks()){
                    NetworkCapabilities cap=cm.getNetworkCapabilities(n);
                    if(cap!=null&&cap.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)){wlan=n;break;}
                }
                if(wlan==null)throw new IOException("请先在系统WiFi设置连接 Lingxian-30，并选择保持连接");
                candidate=wlan.getSocketFactory().createSocket();candidate.setTcpNoDelay(true);
                candidate.connect(new InetSocketAddress("192.168.4.1",3333),5000);
                final Socket connected=candidate;
                ui.post(()->{
                    if(epoch!=wifiEpoch.get()){try{connected.close();}catch(IOException ignored){}replyError(id,"连接已取消");return;}
                    wifiSocket=connected;JSONObject e=event("connected");put(e,"id",id);put(e,"name","Lingxian-30 · WiFi");emit(e);
                    Thread reader=new Thread(()->readWifi(connected,epoch),"lingxian-wifi-read");reader.setDaemon(true);reader.start();
                });
            }catch(Exception ex){
                if(candidate!=null)try{candidate.close();}catch(IOException ignored){}
                replyError(id,"WiFi连接失败："+ex.getMessage());
            }
        });
    }
    private void readWifi(Socket socket,int epoch){
        try{
            byte[] buffer=new byte[1024];int n;
            while((n=socket.getInputStream().read(buffer))!=-1){
                final byte[] bytes=Arrays.copyOf(buffer,n);
                ui.post(()->{if(epoch!=wifiEpoch.get()||socket!=wifiSocket)return;JSONObject e=event("data");put(e,"data",Base64.encodeToString(bytes,Base64.NO_WRAP));emit(e);});
            }
        }catch(IOException ignored){}
        finally{ui.post(()->{if(epoch==wifiEpoch.get()&&socket==wifiSocket)closeWifi(true);});}
    }
    private void writeWifi(int id,String encoded){
        final Socket socket=wifiSocket;final int epoch=wifiEpoch.get();
        wifiIo.execute(()->{
            try{
                if(epoch!=wifiEpoch.get()||socket==null||socket!=wifiSocket)throw new IOException("连接已断开");
                byte[] bytes=Base64.decode(encoded,Base64.DEFAULT);
                if(bytes.length<1||bytes.length>256)throw new IOException("数据长度不正确");
                socket.getOutputStream().write(bytes);socket.getOutputStream().flush();
                JSONObject e=event("written");put(e,"id",id);emit(e);
            }catch(Exception ex){replyError(id,"WiFi发送失败："+ex.getMessage());ui.post(()->{if(epoch==wifiEpoch.get())closeWifi(true);});}
        });
    }
    private void fetchCatalog(int id,String address){network.execute(()->{
        HttpURLConnection connection=null;
        try{
            URL url=new URL(address);if(!"https".equalsIgnoreCase(url.getProtocol()))throw new IOException("曲谱地址须使用HTTPS");
            connection=(HttpURLConnection)url.openConnection();connection.setConnectTimeout(8000);connection.setReadTimeout(8000);
            if(connection.getResponseCode()!=200)throw new IOException("服务器返回 "+connection.getResponseCode());
            if(!"https".equalsIgnoreCase(connection.getURL().getProtocol()))throw new IOException("曲谱地址不再使用HTTPS");
            ByteArrayOutputStream out=new ByteArrayOutputStream();
            try(InputStream in=connection.getInputStream()){
                byte[] b=new byte[4096];int n;while((n=in.read(b))!=-1){if(out.size()+n>1000000)throw new IOException("曲谱库不能超过1MB");out.write(b,0,n);}
            }
            JSONObject e=event("catalog");put(e,"id",id);put(e,"data",Base64.encodeToString(out.toByteArray(),Base64.NO_WRAP));emit(e);
        }catch(Exception e){replyError(id,"曲谱下载失败："+e.getMessage());}finally{if(connection!=null)connection.disconnect();}
    });}
    public final class Bridge {
        @JavascriptInterface public void ready(){emit(event("ready"));}
        @JavascriptInterface public void scan(){ui.post(MainActivity.this::requestScan);}
        @JavascriptInterface public void connect(int id,String address){ui.post(()->MainActivity.this.connect(id,address));}
        @JavascriptInterface public void write(int id,String bytes){ui.post(()->MainActivity.this.write(id,bytes));}
        @JavascriptInterface public void disconnect(){ui.post(()->{stopScan();closeGatt(false);closeWifi(true);});}
        @JavascriptInterface public void fetchCatalog(int id,String address){MainActivity.this.fetchCatalog(id,address);}
    }
    @Override public void onRequestPermissionsResult(int request,String[] permissions,int[] results){
        super.onRequestPermissionsResult(request,permissions,results);
        if(request==PERMISSION_REQUEST&&pendingScan){pendingScan=false;if(permitted())requestScan();else error("权限未开启，可先使用预览；允许蓝牙/附近设备权限后再连接。");}
    }
    @Override protected void onActivityResult(int request,int result,Intent data){
        super.onActivityResult(request,result,data);
        if(request==FILE_REQUEST&&fileCallback!=null){fileCallback.onReceiveValue(result==RESULT_OK&&data!=null?new android.net.Uri[]{data.getData()}:null);fileCallback=null;}
        if(request==ENABLE_BT_REQUEST&&pendingScan){pendingScan=false;if(result==RESULT_OK)requestScan();else error("蓝牙未开启，仍可使用离线预览。");}
    }
    @Override public void onBackPressed(){
        if(web==null){super.onBackPressed();return;}
        web.evaluateJavascript("(function(){var d=document.getElementById('import-dialog');if(d.open){d.close();return true;}if(document.getElementById('page-score').hidden){document.querySelector('[data-page=score]').click();return true;}return false;})()",value->{if("false".equals(value))finish();});
    }
    @Override protected void onDestroy(){stopScan();closeGatt(false);closeWifi(false);wifiIo.shutdownNow();network.shutdownNow();if(fileCallback!=null)fileCallback.onReceiveValue(null);if(web!=null){web.removeJavascriptInterface("AndroidBridge");web.destroy();web=null;}super.onDestroy();}
}

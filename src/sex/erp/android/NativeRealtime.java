package sex.erp.android;

import android.os.Handler;
import android.os.Looper;
import android.util.Base64;
import android.webkit.CookieManager;
import org.json.JSONObject;
import java.io.*;
import java.net.*;
import java.security.*;
import java.util.*;
import java.util.concurrent.*;
import javax.net.ssl.*;

/** Native RFC 6455 connection to the site's existing realtime endpoint. */
final class NativeRealtime {
    interface Listener {void event(String type,JSONObject data);}
    private final NativeApi api;
    private final Listener listener;
    private final Handler ui=new Handler(Looper.getMainLooper());
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
    private final ExecutorService closer=Executors.newSingleThreadExecutor();
    private final SecureRandom random=new SecureRandom();
    private volatile boolean wanted=false, running=false;
    private boolean closed;
    private volatile SSLSocket socket;
    private OutputStream output;
    NativeRealtime(NativeApi api,Listener listener){this.api=api;this.listener=listener;}
    synchronized void connect(){if(closed)return;wanted=true;if(running)return;running=true;worker.execute(this::loop);}
    synchronized void disconnect(){wanted=false;SSLSocket s=socket;if(s!=null&&!closer.isShutdown())closer.execute(()->{try{s.close();}catch(Exception ignored){}});}
    synchronized void close(){if(closed)return;closed=true;disconnect();worker.shutdownNow();closer.shutdown();ui.removeCallbacksAndMessages(null);}
    private void loop(){
        int retry=0;
        while(wanted&&!Thread.currentThread().isInterrupted()) {
            try{open();retry=0;readFrames();}catch(Exception ignored){}
            finally{SSLSocket s=socket;socket=null;output=null;if(s!=null)try{s.close();}catch(IOException ignored){}}
            if(wanted)try{Thread.sleep(Math.min(30000,1000L<<Math.min(retry++,5)));}catch(InterruptedException e){Thread.currentThread().interrupt();break;}
        }
        synchronized(this){running=false;if(wanted&&!worker.isShutdown())connect();}
    }
    private InputStream input;
    private void open()throws Exception {
        SSLSocket s=(SSLSocket)SSLSocketFactory.getDefault().createSocket();socket=s;
        SSLParameters parameters=s.getSSLParameters();parameters.setEndpointIdentificationAlgorithm("HTTPS");s.setSSLParameters(parameters);
        s.connect(new InetSocketAddress("erp.sex",443),15000);s.setSoTimeout(75000);s.startHandshake();
        byte[] nonce=new byte[16];random.nextBytes(nonce);String key=Base64.encodeToString(nonce,Base64.NO_WRAP);
        String cookie=CookieManager.getInstance().getCookie(NativeApi.ORIGIN+"/api/v1/ws");
        String header="GET /api/v1/ws HTTP/1.1\r\nHost: erp.sex\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: "+key+"\r\nOrigin: https://erp.sex\r\nUser-Agent: "+api.userAgent+"\r\n"+(cookie==null?"":"Cookie: "+cookie+"\r\n")+"\r\n";
        output=s.getOutputStream();output.write(header.getBytes("UTF-8"));output.flush();input=new BufferedInputStream(s.getInputStream());
        ByteArrayOutputStream response=new ByteArrayOutputStream();int end=0;
        while(end!=0x0d0a0d0a){int b=input.read();if(b<0||response.size()>16384)throw new IOException("Invalid handshake");response.write(b);end=(end<<8)|b;}
        String[] lines=response.toString("UTF-8").split("\r\n");if(lines.length<2||!lines[0].matches("HTTP/1\\.[01] 101(?: .*|)$"))throw new IOException("Upgrade failed");
        String accept="",upgrade="",connection="";
        for(String line:lines){int colon=line.indexOf(':');if(colon<0)continue;String name=line.substring(0,colon).trim().toLowerCase(Locale.ROOT),value=line.substring(colon+1).trim();if(name.equals("sec-websocket-accept"))accept=value;if(name.equals("upgrade"))upgrade=value;if(name.equals("connection"))connection=value;}
        String expected=Base64.encodeToString(MessageDigest.getInstance("SHA-1").digest((key+"258EAFA5-E914-47DA-95CA-C5AB0DC85B11").getBytes("UTF-8")),Base64.NO_WRAP);
        if(!expected.equals(accept)||!upgrade.equalsIgnoreCase("websocket")||!connection.toLowerCase(Locale.ROOT).contains("upgrade"))throw new IOException("Invalid upgrade");
        send(1,NativeApi.json("type","visibility","data",NativeApi.json("visible",true)).toString().getBytes("UTF-8"));
    }
    private void readFrames()throws Exception {
        ByteArrayOutputStream fragments=new ByteArrayOutputStream();boolean fragment=false;
        while(wanted) {
            WebSocketFrames.Frame frame=WebSocketFrames.readServer(input);boolean finalFrame=frame.fin;int opcode=frame.opcode;byte[] payload=frame.payload;
            if(opcode==8){send(8,payload);return;}if(opcode==9){send(10,payload);continue;}if(opcode==10)continue;
            if(opcode==1){if(fragment)throw new IOException("Unexpected new frame");fragments.reset();fragment=!finalFrame;}
            else if(opcode==0){if(!fragment)throw new IOException("Unexpected continuation");}
            else throw new IOException("Unsupported frame opcode");
            if(fragments.size()+payload.length>2*1024*1024)throw new IOException("Message too large");fragments.write(payload);
            if(!finalFrame)continue;fragment=false;
            JSONObject packet;
            try{packet=new JSONObject(fragments.toString("UTF-8"));}catch(Exception e){continue;}
            String type=packet.optString("type");JSONObject data=packet.optJSONObject("data");if(data==null)data=new JSONObject();
            if(type.equals("ping")){send(1,NativeApi.json("type","pong","data",new JSONObject()).toString().getBytes("UTF-8"));continue;}
            JSONObject value=data;ui.post(()->{if(wanted)listener.event(type,value);});
        }
    }
    // Only the connection worker writes frames; never hold the lifecycle lock during I/O.
    private void send(int opcode,byte[] payload)throws IOException{
        OutputStream target=output;if(target==null)throw new IOException("Disconnected");byte[] mask=new byte[4];random.nextBytes(mask);target.write(WebSocketFrames.client(opcode,payload,mask));target.flush();
    }
}

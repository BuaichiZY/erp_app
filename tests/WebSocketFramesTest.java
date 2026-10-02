package sex.erp.android;

import java.io.*;
import java.util.Arrays;

public final class WebSocketFramesTest {
    private static void check(boolean ok,String name){if(!ok)throw new AssertionError(name);}
    private static void rejects(byte[] bytes,String name)throws Exception{
        try{WebSocketFrames.readServer(new ByteArrayInputStream(bytes));throw new AssertionError(name);}catch(IOException expected){}
    }
    public static void main(String[] args)throws Exception{
        byte[] hello="Hello".getBytes("UTF-8");
        byte[] expected={(byte)0x81,(byte)0x85,0x37,(byte)0xfa,0x21,0x3d,0x7f,(byte)0x9f,0x4d,0x51,0x58};
        check(Arrays.equals(WebSocketFrames.client(1,hello,new byte[]{0x37,(byte)0xfa,0x21,0x3d}),expected),"RFC 6455 masked Hello vector");
        WebSocketFrames.Frame frame=WebSocketFrames.readServer(new ByteArrayInputStream(new byte[]{(byte)0x81,5,72,101,108,108,111}));
        check(frame.fin&&frame.opcode==1&&Arrays.equals(frame.payload,hello),"Server text frame");
        WebSocketFrames.Frame part=WebSocketFrames.readServer(new ByteArrayInputStream(new byte[]{1,2,72,101}));
        check(!part.fin&&part.opcode==1,"Fragment start");
        byte[] longPayload=new byte[65536];byte[] wire=WebSocketFrames.client(1,longPayload,new byte[4]);
        check(wire[1]==(byte)255&&wire[7]==1&&wire[8]==0&&wire[9]==0&&wire.length==65550,"64-bit length boundary");
        byte[] medium=WebSocketFrames.client(1,new byte[126],new byte[4]);
        check(medium[1]==(byte)254&&medium[2]==0&&medium[3]==126,"16-bit length boundary");
        rejects(new byte[]{(byte)0x81,(byte)0x80},"Masked server frame");
        rejects(new byte[]{(byte)0xc1,0},"Unnegotiated extension");
        rejects(new byte[]{9,0},"Fragmented control frame");
        rejects(new byte[]{(byte)0x89,126,0,126},"Oversized control frame");
        rejects(new byte[]{(byte)0x81,127,0,0,0,0,0,0x40,0,0},"Oversized message without allocation");
        rejects(new byte[]{(byte)0x81,2,72},"Truncated payload");
        rejects(new byte[]{(byte)0x81,127,(byte)0x80,0,0,0,0,0,0,0},"Negative 64-bit length");
        System.out.println("12 framing checks passed");
    }
}

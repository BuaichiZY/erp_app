package sex.erp.android;

import java.io.*;

/** Bounded RFC 6455 framing, independent of Android and the site's JSON schema. */
final class WebSocketFrames {
    static final int LIMIT=2*1024*1024;
    static final class Frame {
        final boolean fin;final int opcode;final byte[] payload;
        Frame(boolean fin,int opcode,byte[] payload){this.fin=fin;this.opcode=opcode;this.payload=payload;}
    }
    static Frame readServer(InputStream input)throws IOException{
        int first=one(input),second=one(input);boolean fin=(first&128)!=0;int opcode=first&15;
        if((first&112)!=0||(second&128)!=0)throw new IOException("Reserved bits or masked server frame");
        long length=second&127;
        if(length==126)length=(one(input)<<8)|one(input);
        else if(length==127){length=0;for(int i=0;i<8;i++)length=(length<<8)|one(input);}
        if(length<0||length>LIMIT||((opcode&8)!=0&&(!fin||length>125)))throw new IOException("Invalid frame length");
        byte[] data=new byte[(int)length];int offset=0;
        while(offset<data.length){int n=input.read(data,offset,data.length-offset);if(n<0)throw new EOFException();if(n==0)continue;offset+=n;}
        return new Frame(fin,opcode,data);
    }
    static byte[] client(int opcode,byte[] payload,byte[] mask)throws IOException{
        if(mask.length!=4||payload.length>LIMIT||((opcode&8)!=0&&payload.length>125))throw new IOException("Invalid client frame");
        ByteArrayOutputStream out=new ByteArrayOutputStream(payload.length+14);out.write(128|opcode);int n=payload.length;
        if(n<126)out.write(128|n);
        else if(n<65536){out.write(128|126);out.write(n>>8);out.write(n);}
        else{out.write(128|127);for(int i=7;i>=0;i--)out.write((int)((long)n>>(i*8))&255);}
        out.write(mask);for(int i=0;i<n;i++)out.write(payload[i]^mask[i%4]);return out.toByteArray();
    }
    private static int one(InputStream input)throws IOException{int value=input.read();if(value<0)throw new EOFException();return value;}
}

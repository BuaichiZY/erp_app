package sex.erp.android;

import io.nayuki.qrcodegen.QrCode;
import com.google.zxing.BinaryBitmap;
import com.google.zxing.MultiFormatReader;
import com.google.zxing.RGBLuminanceSource;
import com.google.zxing.common.HybridBinarizer;

public final class QrRoundTripTest {
    public static void main(String[] args)throws Exception {
        String link="https://erp.sex/s/user_example_123?invite=HELLO";
        QrCode qr=QrCode.encodeText(link,QrCode.Ecc.MEDIUM);
        int scale=5,margin=4,width=(qr.size+margin*2)*scale;
        int[] pixels=new int[width*width];
        for(int y=0;y<width;y++)for(int x=0;x<width;x++){
            int col=x/scale-margin,row=y/scale-margin;
            boolean dark=col>=0&&col<qr.size&&row>=0&&row<qr.size&&qr.getModule(col,row);
            pixels[y*width+x]=dark?0xff000000:0xffffffff;
        }
        String decoded=new MultiFormatReader().decode(new BinaryBitmap(new HybridBinarizer(new RGBLuminanceSource(width,width,pixels)))).getText();
        if(!link.equals(decoded))throw new AssertionError("QR link did not round-trip");
        System.out.println("QR share link round-trip passed");
    }
}

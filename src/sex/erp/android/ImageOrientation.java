package sex.erp.android;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Matrix;
import android.media.ExifInterface;
import android.net.Uri;
import java.io.InputStream;

final class ImageOrientation {
    static Bitmap upright(Context context,Uri uri,Bitmap image){
        int orientation=1;
        try(InputStream input=context.getContentResolver().openInputStream(uri)){if(input!=null)orientation=new ExifInterface(input).getAttributeInt(ExifInterface.TAG_ORIENTATION,1);}catch(Exception ignored){}
        Matrix transform=new Matrix();
        switch(orientation){
            case 2:transform.setScale(-1,1);break;
            case 3:transform.setRotate(180);break;
            case 4:transform.setScale(1,-1);break;
            case 5:transform.setRotate(90);transform.postScale(-1,1);break;
            case 6:transform.setRotate(90);break;
            case 7:transform.setRotate(-90);transform.postScale(-1,1);break;
            case 8:transform.setRotate(-90);break;
            default:return image;
        }
        Bitmap rotated=Bitmap.createBitmap(image,0,0,image.getWidth(),image.getHeight(),transform,true);
        if(rotated!=image)image.recycle();return rotated;
    }
}

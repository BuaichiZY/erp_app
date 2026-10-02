package sex.erp.android;

import android.content.Context;
import android.graphics.Bitmap;
import android.widget.ImageView;

/** Locked previews never display an unprocessed full-resolution frame. */
final class ObscuredPhotoView extends ImageView {
    ObscuredPhotoView(Context context){super(context);}
    @Override public void setImageBitmap(Bitmap source){if(source==null){super.setImageBitmap(null);return;}Bitmap small=Bitmap.createScaledBitmap(source,6,6,true);Bitmap obscured=Bitmap.createScaledBitmap(small,48,48,true);if(small!=source)small.recycle();super.setImageBitmap(obscured);}
}

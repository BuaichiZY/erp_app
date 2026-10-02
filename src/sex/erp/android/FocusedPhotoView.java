package sex.erp.android;

import android.content.Context;
import android.graphics.Matrix;
import android.graphics.drawable.Drawable;
import android.widget.ImageView;

/** Preserve the profile owner's crop position, equivalent to CSS object-position. */
class FocusedPhotoView extends ImageView {
    private float focusX=.5f,focusY=.5f;
    FocusedPhotoView(Context context){super(context);setScaleType(ScaleType.MATRIX);}
    void focus(float x,float y){focusX=Math.max(0,Math.min(1,x));focusY=Math.max(0,Math.min(1,y));crop();}
    @Override public void setImageDrawable(Drawable image){super.setImageDrawable(image);crop();}
    @Override public void setImageBitmap(android.graphics.Bitmap image){super.setImageBitmap(image);crop();}
    @Override protected void onSizeChanged(int w,int h,int oldW,int oldH){super.onSizeChanged(w,h,oldW,oldH);crop();}
    private void crop(){Drawable image=getDrawable();if(image==null||getWidth()==0||getHeight()==0)return;int w=image.getIntrinsicWidth(),h=image.getIntrinsicHeight();if(w<=0||h<=0)return;float scale=Math.max((float)getWidth()/w,(float)getHeight()/h);Matrix m=new Matrix();m.setScale(scale,scale);m.postTranslate((getWidth()-w*scale)*focusX,(getHeight()-h*scale)*focusY);setImageMatrix(m);}
}

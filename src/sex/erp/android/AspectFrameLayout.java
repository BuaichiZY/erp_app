package sex.erp.android;

import android.content.Context;
import android.widget.FrameLayout;

final class AspectFrameLayout extends FrameLayout {
    private final float ratio;
    AspectFrameLayout(Context context,float ratio){super(context);this.ratio=ratio;}
    @Override protected void onMeasure(int width,int height){int w=MeasureSpec.getSize(width);super.onMeasure(width,MeasureSpec.makeMeasureSpec(Math.round(w/ratio),MeasureSpec.EXACTLY));}
}

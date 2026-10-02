package sex.erp.android;

import android.content.Context;
import android.view.View;
import android.view.ViewGroup;

/** Wrap compact native chips to the available phone width. */
final class FlowLayout extends ViewGroup {
    private final int gap;
    FlowLayout(Context context){super(context);gap=Math.round(8*getResources().getDisplayMetrics().density);}
    @Override protected void onMeasure(int widthSpec,int heightSpec){
        int width=MeasureSpec.getSize(widthSpec),available=Math.max(0,width-getPaddingLeft()-getPaddingRight()),x=0,y=0,line=0;
        for(int i=0;i<getChildCount();i++){View child=getChildAt(i);if(child.getVisibility()==GONE)continue;child.measure(MeasureSpec.makeMeasureSpec(available,MeasureSpec.AT_MOST),MeasureSpec.makeMeasureSpec(0,MeasureSpec.UNSPECIFIED));int w=child.getMeasuredWidth(),h=child.getMeasuredHeight();if(x>0&&x+w>available){x=0;y+=line+gap;line=0;}x+=w+gap;line=Math.max(line,h);}
        setMeasuredDimension(resolveSize(width,widthSpec),resolveSize(y+line+getPaddingTop()+getPaddingBottom(),heightSpec));
    }
    @Override protected void onLayout(boolean changed,int l,int t,int r,int b){
        int available=r-l-getPaddingLeft()-getPaddingRight(),x=0,y=getPaddingTop(),line=0;
        for(int i=0;i<getChildCount();i++){View child=getChildAt(i);if(child.getVisibility()==GONE)continue;int w=child.getMeasuredWidth(),h=child.getMeasuredHeight();if(x>0&&x+w>available){x=0;y+=line+gap;line=0;}int left=getPaddingLeft()+x;child.layout(left,y,left+w,y+h);x+=w+gap;line=Math.max(line,h);}
    }
    @Override protected LayoutParams generateDefaultLayoutParams(){return new LayoutParams(LayoutParams.WRAP_CONTENT,LayoutParams.WRAP_CONTENT);}
}

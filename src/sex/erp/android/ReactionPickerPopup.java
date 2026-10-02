package sex.erp.android;

import android.content.Context;
import android.graphics.Rect;
import android.graphics.drawable.GradientDrawable;
import android.view.*;
import android.widget.*;
import org.json.JSONArray;
import java.util.Set;
import java.util.function.Consumer;

/** The website's eight-column picker anchored to the image, without a modal dialog. */
final class ReactionPickerPopup {
    static PopupWindow show(Context context,View anchor,ThemePalette palette,JSONArray emojis,Set<String> existing,Set<String> mine,Consumer<String> pick){
        float density=context.getResources().getDisplayMetrics().density;int padding=Math.round(8*density);
        Rect frame=new Rect();anchor.getWindowVisibleDisplayFrame(frame);
        int width=Math.min(Math.round(296*density),Math.max(1,frame.width()-padding*2)),cell=(width-padding*2)/8;
        GridLayout grid=new GridLayout(context);grid.setColumnCount(8);grid.setPadding(padding,padding,padding,padding);
        GradientDrawable bg=new GradientDrawable();bg.setColor(palette.surface);bg.setCornerRadius(16*density);bg.setStroke(Math.max(1,Math.round(density)),palette.border);grid.setBackground(bg);
        PopupWindow popup=new PopupWindow(grid,width,-2,true);popup.setBackgroundDrawable(bg);popup.setElevation(10*density);popup.setOutsideTouchable(true);popup.setClippingEnabled(true);
        popup.setIsLaidOutInScreen(true);
        if(android.os.Build.VERSION.SDK_INT>=29)popup.setIsClippedToScreen(true);
        // Color emoji inherits the text paint alpha. The platform dialog theme defaults
        // to translucent secondary text, which also washes out bitmap emoji glyphs.
        for(int i=0;i<emojis.length();i++){String emoji=emojis.optString(i);if(emoji.isEmpty())continue;TextView choice=new TextView(context);choice.setText(emoji);choice.setTextColor(android.graphics.Color.BLACK);choice.setTextSize(20);choice.setGravity(Gravity.CENTER);choice.setContentDescription(emoji+(mine.contains(emoji)?UiStrings.t("，已添加"):""));boolean allowed=existing.size()<ReactionRules.MAX_KINDS||existing.contains(emoji);choice.setEnabled(allowed);choice.setAlpha(allowed?1:.3f);if(mine.contains(emoji)){GradientDrawable selected=new GradientDrawable();selected.setColor(palette.soft);selected.setCornerRadius(8*density);choice.setBackground(selected);}choice.setOnClickListener(v->{popup.dismiss();pick.accept(emoji);});GridLayout.LayoutParams lp=new GridLayout.LayoutParams();lp.width=cell;lp.height=cell;grid.addView(choice,lp);}
        grid.measure(View.MeasureSpec.makeMeasureSpec(width,View.MeasureSpec.EXACTLY),View.MeasureSpec.makeMeasureSpec(Math.max(1,frame.height()-padding*2),View.MeasureSpec.AT_MOST));
        int height=grid.getMeasuredHeight();int[] location=new int[2];anchor.getLocationOnScreen(location);int x=Math.max(frame.left+padding,Math.min(frame.right-padding-width,location[0]+anchor.getWidth()-width));int y=location[1]+anchor.getHeight()+Math.round(6*density);if(y+height>frame.bottom-padding)y=Math.max(frame.top+padding,location[1]-height-Math.round(6*density));
        popup.showAtLocation(anchor,Gravity.TOP|Gravity.LEFT,x,y);grid.setAlpha(0);grid.setScaleX(.96f);grid.setScaleY(.96f);grid.setPivotX(width);grid.setPivotY(y<location[1]?height:0);grid.animate().alpha(1).scaleX(1).scaleY(1).setDuration(150).start();return popup;
    }
}

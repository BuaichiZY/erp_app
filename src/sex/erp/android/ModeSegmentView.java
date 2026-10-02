package sex.erp.android;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.animation.DecelerateInterpolator;
import android.widget.*;
import java.util.function.Consumer;

/** Selected text expands while the other two labels collapse, matching the website. */
final class ModeSegmentView extends LinearLayout {
    private final String[] modes={"sfw","mixed","nsfw"},labels={"SFW","混合","NSFW"};
    private final TextView[] text=new TextView[3];
    private final SiteIconView[] icons=new SiteIconView[3];
    private final LinearLayout[] cells=new LinearLayout[3];
    private final ValueAnimator[] animations=new ValueAnimator[3];
    private ThemePalette palette;
    private String selected;
    ModeSegmentView(Context context,String mode,ThemePalette palette,Consumer<String> change){
        super(context);setOrientation(HORIZONTAL);setGravity(Gravity.CENTER_VERTICAL);setPadding(dp(3),dp(3),dp(3),dp(3));this.palette=palette;selected=mode;
        String[] names={"heart","layers","flame"};
        for(int i=0;i<3;i++){final int index=i;LinearLayout cell=new LinearLayout(context);cell.setGravity(Gravity.CENTER_VERTICAL);cell.setPadding(dp(7),0,dp(7),0);icons[i]=new SiteIconView(context,names[i],palette.muted,false);cell.addView(icons[i],new LayoutParams(dp(16),dp(18)));TextView label=new TextView(context);label.setText(labels[i]);label.setTextSize(11);label.setSingleLine();label.setTypeface(null,Typeface.NORMAL);label.setGravity(Gravity.CENTER_VERTICAL|Gravity.CENTER_HORIZONTAL);text[i]=label;cell.addView(label,new LayoutParams(0,dp(30)));cell.setContentDescription(labels[i]+" 内容模式");cell.setFocusable(true);cell.setOnClickListener(v->change.accept(modes[index]));cells[i]=cell;addView(cell,new LayoutParams(-2,dp(32)));}
        palette(palette);select(mode,false);
    }
    private int dp(int n){return Math.round(n*getResources().getDisplayMetrics().density);}
    private GradientDrawable background(int color){GradientDrawable d=new GradientDrawable();d.setColor(color);d.setCornerRadius(dp(20));return d;}
    void palette(ThemePalette p){palette=p;GradientDrawable bg=background(p.surface2);if(p.pop)bg.setStroke(dp(2),p.border);setBackground(bg);for(int i=0;i<3;i++)style(i,modes[i].equals(selected));}
    private void style(int i,boolean active){boolean adult=active&&i==2;GradientDrawable bg=background(active?(adult?palette.accent:palette.surface):android.graphics.Color.TRANSPARENT);if(active&&palette.pop)bg.setStroke(dp(2),palette.border);cells[i].setBackground(bg);int color=adult?android.graphics.Color.WHITE:(active?palette.text:palette.muted);text[i].setTextColor(color);icons[i].tint(color);cells[i].setSelected(active);cells[i].setContentDescription(labels[i]+" 内容模式"+(active?"，已选中":""));}
    void select(String mode,boolean animate){selected=mode;for(int i=0;i<3;i++){final int index=i;boolean active=modes[i].equals(mode);style(i,active);if(animations[i]!=null)animations[i].cancel();int end=active?(int)Math.ceil(text[i].getPaint().measureText(labels[i]))+dp(4):0;int start=text[i].getLayoutParams().width;float alpha=text[i].getAlpha();if(!animate){text[i].getLayoutParams().width=end;text[i].setAlpha(active?1:0);text[i].requestLayout();continue;}ValueAnimator a=ValueAnimator.ofFloat(0,1);animations[i]=a;a.setDuration(210);a.setInterpolator(new DecelerateInterpolator());a.addUpdateListener(v->{float fraction=(float)v.getAnimatedValue();text[index].getLayoutParams().width=Math.round(start+(end-start)*fraction);text[index].setAlpha(alpha+((active?1:0)-alpha)*fraction);text[index].requestLayout();});a.start();}}
    @Override protected void onDetachedFromWindow(){for(ValueAnimator a:animations)if(a!=null)a.cancel();super.onDetachedFromWindow();}
}

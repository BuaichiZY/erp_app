package sex.erp.android;

import android.graphics.*;
import android.graphics.drawable.GradientDrawable;

/** The site's Pop preset has a hard outline and a short offset shadow. */
final class PopDrawable extends GradientDrawable {
    private final Paint shadow=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final float radius,offset,stroke;
    PopDrawable(int color,float radius,int line,float density){this.radius=radius;offset=3*density;stroke=2.5f*density;setColor(color);setCornerRadius(radius);line(line);}
    void line(int color){shadow.setColor(color);setStroke(Math.max(1,Math.round(stroke)),color);}
    @Override public void draw(Canvas canvas){Rect b=getBounds();if(b.width()<=offset||b.height()<=offset){super.draw(canvas);return;}canvas.drawRoundRect(b.left+offset,b.top+offset,b.right,b.bottom,radius,radius,shadow);canvas.save();canvas.translate(b.left,b.top);canvas.scale((b.width()-offset)/b.width(),(b.height()-offset)/b.height());canvas.translate(-b.left,-b.top);super.draw(canvas);canvas.restore();}
}

package sex.erp.android;

import android.content.Context;
import android.graphics.*;
import android.view.View;

/** Native vector drawings of the site's outlined navigation and action symbols. */
final class SiteIconView extends View {
    private final String icon;
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private int color;
    private boolean filled;
    private final android.graphics.drawable.Drawable original;
    SiteIconView(Context context,String icon,int color,boolean filled){super(context);this.icon=icon;this.color=color;this.filled=filled;String name="chat".equals(icon)?"message_circle":("close".equals(icon)?"x":("undo".equals(icon)?"rotate_ccw":("reaction".equals(icon)?"smile_plus":icon)));int resource=getResources().getIdentifier("site_"+name,"drawable",context.getPackageName());original=resource==0||filled?null:getResources().getDrawable(resource,context.getTheme()).mutate();setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);}
    void filled(boolean value){filled=value;invalidate();}
    void tint(int value){color=value;invalidate();}
    void recolor(ThemePalette old,ThemePalette next){tint(old.recolor(color,next));}
    private void path(Canvas c,float... points){Path p=new Path();p.moveTo(points[0],points[1]);for(int i=2;i<points.length;i+=2)p.lineTo(points[i],points[i+1]);c.drawPath(p,paint);}
    @Override protected void onDraw(Canvas canvas){
        if(original!=null&&!filled){if(!"logo".equals(icon))original.setTint(color);int size=Math.min(getWidth(),getHeight()),x=(getWidth()-size)/2,y=(getHeight()-size)/2;original.setBounds(x,y,x+size,y+size);original.draw(canvas);return;}
        super.onDraw(canvas);float size=Math.min(getWidth(),getHeight());canvas.save();canvas.translate((getWidth()-size)/2,(getHeight()-size)/2);canvas.scale(size/24,size/24);
        paint.setColor(color);paint.setStrokeWidth(1.8f);paint.setStrokeCap(Paint.Cap.ROUND);paint.setStrokeJoin(Paint.Join.ROUND);paint.setStyle(Paint.Style.STROKE);
        Path p=new Path();
        switch(icon){
            case "logo":
                paint.setStyle(Paint.Style.FILL);p.moveTo(4,1);p.lineTo(19,1);p.quadTo(22,1,22,4);p.lineTo(22,17);p.quadTo(22,20,19,20);p.lineTo(19,24);p.lineTo(14,20);p.lineTo(4,20);p.quadTo(1,20,1,17);p.lineTo(1,4);p.quadTo(1,1,4,1);canvas.drawPath(p,paint);
                paint.setColor(0xff101115);canvas.drawRoundRect(3,11,20,18,1,1,paint);paint.setTypeface(Typeface.create("monospace",Typeface.BOLD));paint.setTextAlign(Paint.Align.CENTER);paint.setTextSize(7.2f);canvas.drawText("ERP",11.5f,9.2f,paint);paint.setColor(color);canvas.drawText("SEX",11.5f,16.7f,paint);break;
            case "compass":canvas.drawCircle(12,12,9,paint);path(canvas,16,8,14,14,8,16,10,10,16,8);break;
            case "heart":
                p.moveTo(12,21);p.cubicTo(10,19,2,13,2,7);p.cubicTo(2,1,9,1,12,6);p.cubicTo(15,1,22,1,22,7);p.cubicTo(22,13,14,19,12,21);p.close();if(filled)paint.setStyle(Paint.Style.FILL);canvas.drawPath(p,paint);break;
            case "chat":p.moveTo(21,11);p.cubicTo(21,17,17,21,11,21);p.quadTo(8,21,6,20);p.lineTo(2,22);p.lineTo(3.5f,17);p.quadTo(2,15,2,11);p.cubicTo(2,5,6,2,12,2);p.cubicTo(18,2,21,5,21,11);canvas.drawPath(p,paint);break;
            case "messages":path(canvas,3,3,18,3,18,14,8,14,3,18,3,3);path(canvas,21,8,21,22,16,18,10,18);break;
            case "megaphone":path(canvas,3,8,13,8,21,4,21,20,13,16,3,16,3,8);path(canvas,7,16,9,22,12,22,10,16);canvas.drawLine(13,8,13,16,paint);break;
            case "user":canvas.drawCircle(12,6.5f,4,paint);p.moveTo(4,22);p.lineTo(4,19);p.quadTo(4,14,9,14);p.lineTo(15,14);p.quadTo(20,14,20,19);p.lineTo(20,22);canvas.drawPath(p,paint);break;
            case "undo":path(canvas,3,4,3,10,9,10);p.moveTo(3,10);p.cubicTo(6,2,20,4,20,13);p.cubicTo(20,21,11,24,6,19);canvas.drawPath(p,paint);break;
            case "close":path(canvas,5,5,19,19);path(canvas,19,5,5,19);break;
            case "star":p.moveTo(12,2);p.lineTo(15,8.5f);p.lineTo(22,9.5f);p.lineTo(17,14.5f);p.lineTo(18,22);p.lineTo(12,18.5f);p.lineTo(6,22);p.lineTo(7,14.5f);p.lineTo(2,9.5f);p.lineTo(9,8.5f);p.close();if(filled)paint.setStyle(Paint.Style.FILL);canvas.drawPath(p,paint);break;
            case "bell":p.moveTo(3,18);p.quadTo(6,14,6,9);p.cubicTo(6,1,18,1,18,9);p.quadTo(18,14,21,18);p.close();canvas.drawPath(p,paint);p.reset();p.moveTo(10,22);p.quadTo(12,24,14,22);canvas.drawPath(p,paint);break;
            case "moon":p.moveTo(20,14);p.cubicTo(8,18,6,6,10,2);p.cubicTo(-4,6,3,25,15,21);p.quadTo(20,19,20,14);canvas.drawPath(p,paint);break;
            case "layers":path(canvas,12,3,22,8,12,13,2,8,12,3);path(canvas,2,12,12,17,22,12);path(canvas,2,17,12,22,22,17);break;
            case "flame":p.moveTo(12,2);p.cubicTo(10,8,19,10,14,13);p.quadTo(8,15,7,10);p.cubicTo(-1,20,15,27,20,17);p.cubicTo(23,11,16,8,12,2);canvas.drawPath(p,paint);break;
            case "grid":for(int x=3;x<=13;x+=10)for(int y=3;y<=13;y+=10)canvas.drawRoundRect(x,y,x+7,y+7,1,1,paint);break;
            case "sliders":path(canvas,3,6,7,6);path(canvas,11,6,21,6);canvas.drawCircle(9,6,2,paint);path(canvas,3,18,13,18);path(canvas,17,18,21,18);canvas.drawCircle(15,18,2,paint);break;
            case "reaction":canvas.drawArc(3,3,21,21,0,270,false,paint);canvas.drawCircle(8,10,.6f,paint);canvas.drawCircle(14,10,.6f,paint);canvas.drawArc(7,9,17,17,20,140,false,paint);path(canvas,18,2,18,8);path(canvas,15,5,21,5);break;
            case "sun":canvas.drawCircle(12,12,4,paint);for(int i=0;i<8;i++){double angle=i*Math.PI/4;canvas.drawLine(12+(float)Math.cos(angle)*7,12+(float)Math.sin(angle)*7,12+(float)Math.cos(angle)*10,12+(float)Math.sin(angle)*10,paint);}break;
            case "monitor":canvas.drawRoundRect(2,3,22,17,2,2,paint);path(canvas,12,17,12,21);path(canvas,8,21,16,21);break;
            case "check":path(canvas,4,12,9,17,20,6);break;
            case "zap":p.moveTo(13,2);p.lineTo(4,13);p.lineTo(11,13);p.lineTo(10,22);p.lineTo(20,10);p.lineTo(13,10);p.close();paint.setStyle(Paint.Style.FILL);canvas.drawPath(p,paint);break;
            case "gem":path(canvas,7,3,17,3,22,9,12,22,2,9,7,3);path(canvas,2,9,22,9);path(canvas,7,3,8,9,12,22,16,9,17,3);break;
            case "gamepad":canvas.drawRoundRect(2,6,22,19,4,4,paint);path(canvas,5,12,11,12);path(canvas,8,9,8,15);canvas.drawCircle(16,11,.7f,paint);canvas.drawCircle(19,14,.7f,paint);break;
            case "back":path(canvas,12,4,4,12,12,20);path(canvas,4,12,21,12);break;
            case "more":paint.setStyle(Paint.Style.FILL);canvas.drawCircle(12,5,1.6f,paint);canvas.drawCircle(12,12,1.6f,paint);canvas.drawCircle(12,19,1.6f,paint);break;
            case "image_plus":canvas.drawRoundRect(3,4,21,21,2,2,paint);canvas.drawCircle(8,9,1.5f,paint);path(canvas,4,19,10,13,14,17,18,13,21,16);path(canvas,18,1,18,7);path(canvas,15,4,21,4);break;
            case "mic":canvas.drawRoundRect(9,2,15,15,3,3,paint);canvas.drawArc(6,7,18,19,0,180,false,paint);path(canvas,12,19,12,22);path(canvas,9,22,15,22);break;
            case "send":path(canvas,22,2,15,22,11,13,2,9,22,2);path(canvas,11,13,22,2);break;
            case "search":canvas.drawCircle(10,10,7,paint);path(canvas,15,15,21,21);break;
            case "filter":path(canvas,3,5,21,5);path(canvas,6,12,18,12);path(canvas,10,19,14,19);break;
            case "chevron_down":path(canvas,5,9,12,16,19,9);break;
            case "eye":p.moveTo(2,12);p.quadTo(12,-1,22,12);p.quadTo(12,25,2,12);canvas.drawPath(p,paint);canvas.drawCircle(12,12,3,paint);break;
            case "share":canvas.drawCircle(18,5,3,paint);canvas.drawCircle(6,12,3,paint);canvas.drawCircle(18,19,3,paint);path(canvas,8.6f,10.5f,15.4f,6.5f);path(canvas,8.6f,13.5f,15.4f,17.5f);break;
            case "clock":canvas.drawCircle(12,12,9,paint);path(canvas,12,6,12,12,16,14);break;
            case "users":canvas.drawCircle(9,7,3,paint);p.moveTo(2,21);p.lineTo(2,18);p.quadTo(2,13,7,13);p.lineTo(11,13);p.quadTo(16,13,16,18);p.lineTo(16,21);canvas.drawPath(p,paint);canvas.drawArc(13,4,19,10,-90,180,false,paint);p.reset();p.moveTo(19,13);p.quadTo(22,14,22,18);p.lineTo(22,21);canvas.drawPath(p,paint);break;
            case "flag":path(canvas,4,22,4,3,12,3,15,5,21,5,21,15,15,15,12,13,4,13);break;
            case "ban":canvas.drawCircle(12,12,9,paint);path(canvas,6,6,18,18);break;
            case "feedback":canvas.drawCircle(12,12,9,paint);path(canvas,12,7,12,13);canvas.drawCircle(12,17,.5f,paint);break;
        }
        canvas.restore();
    }
}

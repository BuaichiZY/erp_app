package sex.erp.android;

/** Theme choice is independent of content mode; auto follows the site's appearance. */
final class ThemePalette {
    final boolean dark,pop;
    final int bg,surface,surface2,text,muted,accent,border,image,soft;
    ThemePalette(boolean dark,boolean pop,int accent){this.dark=dark;this.pop=pop;this.accent=accent;
        bg=pop?(dark?0xff1b1233:0xffffeb7a):(dark?0xff101115:0xfff4f5f7);
        // A distinct near-white keeps image/action foreground white out of semantic remapping.
        surface=dark?(pop?0xff271a47:0xff1b1e25):0xfffefefe;
        surface2=pop?(dark?0xff34245d:0xfffff3c4):(dark?0xff23262e:0xffe9ebef);
        text=pop?(dark?0xfffefeff:0xff141415):(dark?0xfff5f5f7:0xff20232a);muted=pop?(dark?0xffcfc4ec:0xff4d4d4d):(dark?0xff9ba0ad:0xff737986);
        border=pop?(dark?0xff0b0618:0xff141414):(dark?0xff30333c:0xffdfe2e7);
        image=surface2;
        soft=dark?(pop?0xff45234f:0xff38252b):0xffffe9e7;
    }
    static boolean dark(String preference,String mode,boolean systemDark,String modeScheme){
        if("light".equals(preference))return false;if("dark".equals(preference))return true;
        if("system".equals(preference))return systemDark;
        return "dark".equals(modeScheme);
    }
    int recolor(int color,ThemePalette next){
        if(color==bg)return next.bg;if(color==surface)return next.surface;if(color==surface2)return next.surface2;
        if(color==text)return next.text;if(color==muted)return next.muted;if(color==accent)return next.accent;
        if(color==border)return next.border;if(color==image)return next.image;if(color==soft)return next.soft;
        return color;
    }
}

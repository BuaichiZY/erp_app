package sex.erp.android;

final class ReactionRules {
    static final int MAX_MINE=3,MAX_KINDS=20;
    static String pick(boolean existing,boolean mine,int mineCount,int kinds){
        if(mine)return "none";
        if(mineCount>=MAX_MINE)return "limit";
        if(!existing&&kinds>=MAX_KINDS)return "full";
        return "add";
    }
}

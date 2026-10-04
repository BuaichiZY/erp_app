package sex.erp.android;

public final class ChatImagePolicyTest {
    private static void check(boolean result,boolean expected){if(result!=expected)throw new AssertionError("Unexpected upload eligibility");}
    public static void main(String[] args){
        check(ChatImagePolicy.valid(false,"general",false,false,true,"",false),false);
        check(ChatImagePolicy.valid(true,"general",false,false,false,"",false),false);
        check(ChatImagePolicy.valid(true,"",false,false,true,"",false),false);
        check(ChatImagePolicy.valid(true,"general",true,true,true,"",false),true);
        check(ChatImagePolicy.valid(true,"suggestive",true,false,true,"",false),false);
        check(ChatImagePolicy.valid(true,"suggestive",false,true,true,"",false),false);
        check(ChatImagePolicy.valid(true,"suggestive",false,false,true,"",false),true);
        check(ChatImagePolicy.valid(true,"r18",false,false,true,"sexual",false),false);
        check(ChatImagePolicy.valid(true,"r18",false,false,true,"",true),false);
        check(ChatImagePolicy.valid(true,"r18",false,false,true,"sexual",true),true);
        check(ChatImagePolicy.valid(true,"r18",false,false,true,"gore",true),true);
        check(ChatImagePolicy.valid(true,"unknown",false,false,true,"",true),false);
        System.out.println("Chat image upload eligibility checks passed: 12");
    }
}

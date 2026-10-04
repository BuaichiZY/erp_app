package sex.erp.android;

public final class ImageSizingTest {
    public static void main(String[] args){
        int avatar=ImageSizing.bucket(108,108),cover=ImageSizing.bucket(1040,1200);
        if(avatar!=160||cover<1200)throw new AssertionError();
        int sample=ImageSizing.sample(4096,4096,avatar);
        if(4096/sample<avatar||4096/sample>=avatar*2)throw new AssertionError();
        if(ImageSizing.sample(360,360,cover)!=1)throw new AssertionError("Never reduce a small preview");
        if(ImageSizing.bucket(99999,99999)!=1600)throw new AssertionError("Bound decoded image size");
        if(ImageSizing.sample(0,0,160)!=1)throw new AssertionError();
        System.out.println("Image sizing: avatar memory savings and large-image quality passed");
    }
}

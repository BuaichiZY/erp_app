package sex.erp.android;

/** Decode for the display area, rather than allocating a full photo for an avatar. */
final class ImageSizing {
    static int bucket(int width,int height){int edge=Math.max(width,height);for(int size:new int[]{160,320,640,960,1280,1600})if(edge<=size)return size;return 1600;}
    static int sample(int width,int height,int edge){int sample=1;while(Math.max(width,height)/(sample*2)>=Math.max(1,edge))sample*=2;return sample;}
}

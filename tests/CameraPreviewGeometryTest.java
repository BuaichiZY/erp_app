package sex.erp.android;

public final class CameraPreviewGeometryTest {
    private static void close(float actual,float expected){if(Math.abs(actual-expected)>0.001f)throw new AssertionError(actual+" != "+expected);}
    public static void main(String[] args){
        int[][] windows={{1080,1460},{1080,1920},{1920,1080},{800,600},{600,800},{942,1250}};
        int[][] buffers={{640,480},{1280,720},{1440,1080}};
        for(int[] window:windows)for(int[] buffer:buffers)for(int sensor:new int[]{0,90,180,270})for(int display:new int[]{0,90,180,270}){
            CameraPreviewGeometry fit=CameraPreviewGeometry.centerCrop(window[0],window[1],buffer[0],buffer[1],sensor,display);
            float sourceWidth=sensor%180==0?buffer[0]:buffer[1],sourceHeight=sensor%180==0?buffer[1]:buffer[0];
            // A circle in the sensor image must have equal horizontal and vertical radii.
            close(fit.scaleX*window[0]/sourceWidth*fit.fillScale,fit.scaleY*window[1]/sourceHeight*fit.fillScale);
            float displayedWidth=(display%180==0?sourceWidth:sourceHeight)*fit.fillScale;
            float displayedHeight=(display%180==0?sourceHeight:sourceWidth)*fit.fillScale;
            if(displayedWidth+0.001f<window[0]||displayedHeight+0.001f<window[1])throw new AssertionError("Preview leaves a gap");
            if(Math.abs(displayedWidth-window[0])>0.001f&&Math.abs(displayedHeight-window[1])>0.001f)throw new AssertionError("Unnecessary crop");
            close(fit.rotation,-display);
        }
        try{CameraPreviewGeometry.centerCrop(0,100,640,480,90,0);throw new AssertionError("Empty viewport accepted");}catch(IllegalArgumentException expected){}
        System.out.println("Camera preview preserves aspect ratio and fills resized/rotated viewports");
    }
}

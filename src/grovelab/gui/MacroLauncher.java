package grovelab.gui;

import ij.IJ;
import java.io.InputStream;

/**
 * Created by Grove-Lab on 23/03/2016.
 */
public class MacroLauncher {

    public static void runMacro(String path) {
        // Open and check input stream
        InputStream is = MacroLauncher.class.getResourceAsStream(path);
        if (is == null) {
            IJ.error("File " + path + " was not found inside JAR.");
            return;
        }
        String macroString = convertStreamToString(is);
        IJ.runMacro(macroString);
    }

    public static String convertStreamToString(java.io.InputStream is) {
        java.util.Scanner s = new java.util.Scanner(is).useDelimiter("\\A");
        return s.hasNext() ? s.next() : "";
    }
}

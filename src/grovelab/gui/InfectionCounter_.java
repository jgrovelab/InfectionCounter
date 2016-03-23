package grovelab.gui;

import ij.plugin.PlugIn;
import static grovelab.gui.MacroLauncher.runMacro;

/**
 * Created by Grove-Lab on 23/03/2016.
 */
public class InfectionCounter_ implements PlugIn {

    @Override
    public void run(String s) {
        String path = "/InfectionCounter.ijm";
        runMacro(path);
    }

}

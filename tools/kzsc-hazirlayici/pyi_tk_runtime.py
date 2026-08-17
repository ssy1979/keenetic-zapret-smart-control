"""Point frozen Tkinter at the bundled Tcl/Tk script libraries."""

import os
import sys


base = getattr(sys, "_MEIPASS", os.path.dirname(sys.executable))
os.environ["TCL_LIBRARY"] = os.path.join(base, "_tcl_data")
os.environ["TK_LIBRARY"] = os.path.join(base, "_tk_data")

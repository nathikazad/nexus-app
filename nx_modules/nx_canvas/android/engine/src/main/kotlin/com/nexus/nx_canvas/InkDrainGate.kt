package com.nexus.nx_canvas

import kotlin.math.*

class InkDrainGate {
    private var outstanding=0
    private var down=false
    val pending get()=synchronized(this){down || outstanding>0}
    @Synchronized fun begin(){outstanding++;down=true}
    @Synchronized fun end(){down=false}
    @Synchronized fun complete(){outstanding=(outstanding-1).coerceAtLeast(0)}
    /** Only called after the firmware confirms all submitted points were processed. */
    @Synchronized fun reconcileReleased(){if(!down)outstanding=0}
    @Synchronized fun cancel(){if(down)outstanding=(outstanding-1).coerceAtLeast(0);down=false}
}

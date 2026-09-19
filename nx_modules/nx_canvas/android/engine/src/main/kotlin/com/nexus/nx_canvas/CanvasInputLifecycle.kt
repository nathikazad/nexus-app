package com.nexus.nx_canvas

/** Raw packets and tool commands have one owner and one FIFO. Platform-free, owner-thread API. */
data class CanvasPenPacket(val action:Int,val x:Int,val y:Int,val pressure:Int,val tool:Int) {
    fun up()=copy(action=3,pressure=0)
    fun down()=copy(action=1)
}
data class CanvasPenTool(val tool:NativeTool,val width:Double)
interface CanvasFirmwarePort {
    fun send(packet:CanvasPenPacket)
    fun isDrained():Boolean
    fun finishPendingStroke()
    fun changeTool(tool:CanvasPenTool)
}
class CanvasInputLifecycle(
    private val port:CanvasFirmwarePort, private val scheduler:CanvasScheduler,
    private val diagnostic:DiagnosticSink=NoCanvasDiagnostics,
    private val fault:(String)->Unit,
) {
    private sealed class Command {
        data class Point(val packet:CanvasPenPacket):Command()
        data class Tool(val value:CanvasPenTool):Command()
        class Drain(val done:(Boolean)->Unit):Command() {
            private var replied=false
            fun reply(ok:Boolean){if(!replied){replied=true;done(ok)}}
        }
    }
    private val queue=java.util.ArrayDeque<Command>()
    private var waiting:Command?=null
    private var restart:CanvasPenPacket?=null
    private var last:CanvasPenPacket?=null
    private var penDown=false
    private var accepting=false
    private var pumping=false
    private var closed=false
    private var timeout:Cancellation?=null
    private var current:CanvasPenTool?=null
    fun enable(value:Boolean){
        accepting=value && !closed
        if(accepting && waiting!=null){port.finishPendingStroke();pump()}
    }
    fun submit(packet:CanvasPenPacket) {
        if(!accepting || closed)return
        queue.add(Command.Point(packet));pump()
    }
    fun tool(value:CanvasPenTool) {
        if(closed)return
        // Coalesce tool intents only when there is no intervening input.
        if(queue.peekLast() is Command.Tool)queue.removeLast()
        queue.add(Command.Tool(value));pump()
    }
    fun drain(done:(Boolean)->Unit) {
        if(closed){done(false);return}
        accepting=false
        if(waiting!=null)port.finishPendingStroke()
        queue.add(Command.Drain(done));pump()
    }
    fun progressed(){pump()}
    private fun send(packet:CanvasPenPacket) {
        // Firmware tool 2 is a finger/palm; it cannot start, end or relocate a pen segment.
        if(packet.tool==2){port.send(packet);return}
        // A duplicate down terminates the old segment explicitly instead of abandoning it.
        if(packet.action==1 && penDown)last?.let{port.send(it.up())}
        // Resume after a deliberate drain if contact is still moving.
        if(packet.action==2 && !penDown)port.send(packet.down())
        port.send(packet)
        if(packet.action==1 || packet.action==2)penDown=true
        if(packet.action==3)penDown=false
        last=packet
    }
    private fun pump() {
        if(pumping || closed)return
        pumping=true
        try {
            while(true) {
                val barrier=waiting
                if(barrier!=null) {
                    if(!port.isDrained())return
                    waiting=null;timeout?.cancel();timeout=null
                    diagnostic.event("input.transition_drained")
                    when(barrier) {
                        is Command.Tool -> {
                            try { port.changeTool(barrier.value) }
                            catch(error:Throwable) {
                                waiting=barrier;accepting=false
                                diagnostic.event("input.tool_failed",mapOf("error_type" to error.javaClass.name))
                                fault("The tool could not be changed. Tap Retry input.")
                                return
                            }
                            current=barrier.value
                            restart?.let{send(it.down())};restart=null
                        }
                        is Command.Drain -> barrier.reply(true)
                        else -> error("Invalid input barrier")
                    }
                }
                val command=queue.pollFirst()?:return
                if(command is Command.Point){send(command.packet);continue}
                if(command is Command.Tool && command.value==current)continue
                waiting=command
                restart=if(command is Command.Tool && penDown)last else null
                if(penDown){last?.let{port.send(it.up())};penDown=false}
                diagnostic.event("input.transition_wait",mapOf("kind" to if(command is Command.Tool)"tool" else "drain","queued" to queue.size))
                timeout=scheduler.after(2000) {
                    if(waiting===command) {
                        // Keep packets and barrier intact. Progress/retry can complete it later.
                        accepting=false
                        fault("Input has not finished. Lift the pen and tap Retry input.")
                        diagnostic.event("input.transition_timeout",mapOf("queued" to queue.size))
                        if(command is Command.Drain)command.reply(false)
                    }
                }
            }
        } finally {pumping=false}
    }
    fun close(){closed=true;accepting=false;timeout?.cancel();timeout=null;queue.clear();waiting=null}
}

package com.nexus.nx_canvas

import java.io.*
import java.util.zip.CRC32

/** Single-writer, checksummed append log. Only changed stroke points are serialized.
 * A torn final frame is ignored; a corrupt first frame is an error, never an empty drawing.
 * Compaction replaces the log atomically only after the replacement is flushed.
 */
class InkJournal(private val file:File,private val compactEvery:Int=128) : CanvasRecoveryStore {
    data class Saved(val documentId:String,val title:String,val snapshot:InkSnapshot,val token:String) {
        fun payload():Map<String,Any> = mapOf("documentId" to documentId,"title" to title,
            "drawing" to InkCodec.encode(snapshot.model()),"saveToken" to token)
    }
    override fun recover(): CanvasRecovery? = read()?.let { CanvasRecovery(it.documentId, it.title, it.snapshot, it.token) }
    private var loaded=false
    private var current:Saved?=null
    private var validBytes=0L
    private var frames=0
    @Synchronized fun read():Saved? {
        if(loaded)return current
        if(file.exists())RandomAccessFile(file,"r").use { input ->
            while(input.filePointer<input.length()) {
                val frame=try {
                    val count=input.readInt();require(count in 1..128*1024*1024)
                    val crc=input.readLong();val bytes=ByteArray(count);input.readFully(bytes)
                    require(CRC32().apply{update(bytes)}.value==crc)
                    decode(bytes,current)
                } catch(error:Exception) {
                    if(current==null)throw IOException("Canvas recovery journal is damaged",error)
                    break
                }
                current=frame;validBytes=input.filePointer;frames++
            }
        }
        loaded=true;return current
    }
    @Synchronized override fun save(documentId:String,title:String,snapshot:InkSnapshot,token:String) {
        val previous=read()
        require(previous==null || previous.documentId==documentId){"Another canvas has unsaved changes"}
        val next=Saved(documentId,title,snapshot,token)
        val compact=frames>=compactEvery || validBytes>16*1024*1024
        val bytes=encode(next,if(compact)null else previous)
        file.parentFile?.mkdirs()
        if(compact) {
            val temporary=File(file.path+".compact")
            RandomAccessFile(temporary,"rw").use{it.setLength(0);writeFrame(it,bytes);it.fd.sync()}
            if(!temporary.renameTo(file))throw IOException("Could not compact canvas recovery")
            validBytes=file.length();frames=1
        } else {
            RandomAccessFile(file,"rw").use {
                it.setLength(validBytes);it.seek(validBytes);writeFrame(it,bytes);it.fd.sync()
                validBytes=it.filePointer
            }
            frames++
        }
        current=next
    }
    @Synchronized override fun acknowledge(token:String):Boolean {
        if(read()?.token!=token)return false
        if(file.exists() && !file.delete())throw IOException("Could not acknowledge canvas recovery")
        current=null;validBytes=0;frames=0;loaded=true;return true
    }
    private fun writeFrame(out:RandomAccessFile,bytes:ByteArray) {
        out.writeInt(bytes.size);out.writeLong(CRC32().apply{update(bytes)}.value);out.write(bytes)
    }
    private fun encode(next:Saved,previous:Saved?):ByteArray {
        val bytes=ByteArrayOutputStream()
        DataOutputStream(bytes).use { out ->
            out.writeInt(1);out.writeBoolean(previous==null)
            out.writeUTF(next.documentId);out.writeUTF(next.title);out.writeUTF(next.token)
            val old=previous?.snapshot?.strokes?.associateBy{it.id}.orEmpty()
            val changed=next.snapshot.strokes.filter{old[it.id]!==it}
            out.writeInt(changed.size)
            for(s in changed) {
                out.writeUTF(s.id);out.writeLong(s.color);out.writeDouble(s.width);out.writeInt(s.points.size)
                for(p in s.points){out.writeDouble(p.x);out.writeDouble(p.y);out.writeDouble(p.pressure)}
            }
            out.writeInt(next.snapshot.strokes.size);next.snapshot.strokes.forEach{out.writeUTF(it.id)}
            fun view(v:InkViewport){out.writeDouble(v.x);out.writeDouble(v.y);out.writeDouble(v.scale)}
            view(next.snapshot.view)
            out.writeInt(next.snapshot.places.size);next.snapshot.places.forEach{out.writeUTF(it.name);view(it.view)}
            out.writeBoolean(next.snapshot.boards!=null)
            next.snapshot.boards?.let{out.writeDouble(it.width);out.writeDouble(it.height)}
        }
        return bytes.toByteArray()
    }
    private fun decode(bytes:ByteArray,previous:Saved?):Saved=DataInputStream(ByteArrayInputStream(bytes)).use { input ->
        require(input.readInt()==1)
        val full=input.readBoolean()
        val document=input.readUTF();val title=input.readUTF();val token=input.readUTF()
        require(full || previous?.documentId==document)
        val strokes=if(full)mutableMapOf() else previous!!.snapshot.strokes.associateBy{it.id}.toMutableMap()
        fun count():Int=input.readInt().also{require(it in 0..10_000_000)}
        repeat(count()) {
            val id=input.readUTF();val color=input.readLong();val width=input.readDouble()
            val points=List(count()){InkPoint(input.readDouble(),input.readDouble(),input.readDouble())}
            strokes[id]=NativeStroke(id,points,color,width)
        }
        val ordered=List(count()){strokes[input.readUTF()]?:error("Missing journal stroke")}
        fun view()=InkViewport(input.readDouble(),input.readDouble(),input.readDouble())
        val viewport=view();val places=List(count()){InkPlace(input.readUTF(),view())}
        val boards=if(input.readBoolean())InkBoards(input.readDouble(),input.readDouble()) else null
        require(input.available()==0)
        Saved(document,title,InkSnapshot(ordered,viewport,places,boards),token)
    }
}

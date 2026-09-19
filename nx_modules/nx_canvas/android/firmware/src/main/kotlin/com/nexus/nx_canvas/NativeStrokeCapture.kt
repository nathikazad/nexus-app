package com.nexus.nx_canvas

import java.util.UUID

/** Runs on the import worker, never on the firmware's drawing thread. */
object NativeStrokeCapture {
    fun decode(record:Any,transform:InputTransform):InkOperation? {
        val cls=record.javaClass;val type=cls.getField("type").getInt(record)
        if(type !in listOf(101,201,202))return null
        val raw=cls.getField("points").get(record) as? List<*>?:return null
        val max=(cls.getField("maxPressure").get(record) as Number).toDouble()
        val min=(cls.getField("minPressure").get(record) as Number).toDouble()
        val pc=raw.firstOrNull{it!=null}?.javaClass?:return null
        val getX=pc.getMethod("getX");val getY=pc.getMethod("getY");val getPressure=pc.getMethod("getPressure")
        val points=raw.filterNotNull().map{p->
            val x=(getX.invoke(p) as Number).toDouble();val y=(getY.invoke(p) as Number).toDouble()
            val pressure=(getPressure.invoke(p) as Number).toDouble()
            val local=InkCoordinates.panelToView(InkPoint(x,y),transform.rotation,transform.width.toDouble(),transform.height.toDouble())
            val world=transform.view.world(InkPoint(local.x/transform.density,local.y/transform.density))
            InkPoint(world.x,world.y,if(max>min)((pressure-min)/(max-min)).coerceIn(.1,1.0)else 1.0)
        }
        if(points.isEmpty())return null
        val width=cls.getField("strokeWidth").getInt(record)/transform.density/transform.view.scale
        // Only SimplePenRecord owns color. Rubber/RegionRubber inherit BaseRecord;
        // their operation is geometry-only and has no color field in the firmware.
        val color=if(type==101)cls.getField("color").getInt(record).toLong() and 0xffffffffL else 0L
        return InkOperation(when(type) {101->InkOperationKind.DRAW;201->InkOperationKind.ERASE_PATH;else->InkOperationKind.ERASE_REGION},NativeStroke(UUID.randomUUID().toString(),points,
            color,width))
    }
}

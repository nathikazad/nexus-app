package com.nexus.nx_canvas

import kotlin.math.*

data class InkSnapshot(val strokes:List<NativeStroke>,val view:InkViewport,val places:List<InkPlace>,val boards:InkBoards?) {
    fun model()=InkModel(strokes,view,places,boards)
    companion object { fun of(model:InkModel)=InkSnapshot(model.strokes,model.view,model.places,model.boards) }
}

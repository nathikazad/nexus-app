package com.nexus.nx_canvas

sealed class CanvasCommand {
    object Undo : CanvasCommand()
    object Redo : CanvasCommand()
    object ClearSelection : CanvasCommand()
    object RememberView : CanvasCommand()
    data class ReplaceInk(val strokes: List<NativeStroke>) : CanvasCommand()
    data class SetView(val view: InkViewport) : CanvasCommand()
    data class SetBoards(val boards: InkBoards) : CanvasCommand()
    data class Select(val path: List<InkPoint>) : CanvasCommand()
    data class MoveSelection(val delta: InkPoint) : CanvasCommand()
    data class Zoom(val factor: Double, val anchor: InkPoint) : CanvasCommand()
    data class OpenBoard(val board: InkBoard, val width: Double, val height: Double) : CanvasCommand()
}
/** Single owner of mutable ink/history. Consumers receive detached presentation models.
 * Access is confined to the creating thread; workers receive CanvasRevision snapshots.
 */
class CanvasEngine(val session: String, initial: InkSnapshot) {
    private val owner = Thread.currentThread()
    private val model = initial.model()
    private var revision = 0L
    private fun checkOwner() = check(Thread.currentThread() === owner) { "Canvas engine accessed outside its owner thread" }
    fun snapshot(): CanvasRevision { checkOwner(); return CanvasRevision(session, revision, InkSnapshot.of(model)) }
    fun presentation(): InkModel {
        checkOwner()
        return InkSnapshot.of(model).model().also { it.selected.addAll(model.selected) }
    }
    val canUndo get() = model.canUndo
    val canRedo get() = model.canRedo
    fun dispatch(command: CanvasCommand): CanvasRevision {
        checkOwner()
        val before = InkSnapshot.of(model)
        when (command) {
            CanvasCommand.Undo -> model.undo()
            CanvasCommand.Redo -> model.redo()
            CanvasCommand.ClearSelection -> model.selected.clear()
            CanvasCommand.RememberView -> model.rememberView()
            is CanvasCommand.ReplaceInk -> model.replace(command.strokes)
            is CanvasCommand.SetView -> model.view = command.view
            is CanvasCommand.SetBoards -> model.boards = command.boards
            is CanvasCommand.Select -> model.select(command.path)
            is CanvasCommand.MoveSelection -> model.moveSelection(command.delta)
            is CanvasCommand.Zoom -> model.zoom(command.factor, command.anchor)
            is CanvasCommand.OpenBoard -> { model.selected.clear(); model.view = model.boards!!.view(command.board, command.width, command.height) }
        }
        if (before != InkSnapshot.of(model)) revision++
        return snapshot()
    }
}

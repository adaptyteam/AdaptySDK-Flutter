package com.adapty.flutter

/**
 * The activities of the Flutter engines of the process, one per owner, in the order the owners got them.
 *
 * The native SDK is shared by all engines of the process and uses the activity of the last one, so an
 * engine that loses its activity, such as the engine of an old activity destroyed after a new one has
 * started, doesn't take the activity away from the others. Owners are told apart by identity. One lock
 * guards both the changes and the reads, since the native SDK reads the current activity on its own
 * threads.
 */
internal class ActivityRegistry<O : Any, V : Any> {

    private val entries = mutableListOf<Pair<O, V>>()

    /**
     * Sets the activity of [owner], which then comes last, or removes it when [value] is null.
     */
    fun set(owner: O, value: V?) {
        synchronized(entries) {
            entries.removeAll { it.first === owner }
            if (value != null) entries.add(owner to value)
        }
    }

    /** The activity of the owner that got one last, or null when none has one. */
    fun current(): V? = synchronized(entries) { entries.lastOrNull()?.second }
}

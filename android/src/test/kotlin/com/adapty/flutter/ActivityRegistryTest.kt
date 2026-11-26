package com.adapty.flutter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ActivityRegistryTest {

    private class Engine(val name: String) {
        override fun toString() = name
    }

    private val registry = ActivityRegistry<Engine, String>()

    @Test
    fun `there is no activity before any engine attaches`() {
        assertNull(registry.current())
    }

    @Test
    fun `the activity of the engine that attached last is the current one`() {
        val first = Engine("first")
        val second = Engine("second")
        val third = Engine("third")

        registry.set(first, "activity of first")
        assertEquals("activity of first", registry.current())
        registry.set(second, "activity of second")
        assertEquals("activity of second", registry.current())
        registry.set(third, "activity of third")
        assertEquals("activity of third", registry.current())
    }

    @Test
    fun `an old engine that detaches while a new one is attached leaves the activity of the new one`() {
        val old = Engine("old")
        val new = Engine("new")

        registry.set(old, "old activity")
        registry.set(new, "new activity")
        registry.set(old, null)

        assertEquals("new activity", registry.current())
    }

    @Test
    fun `a new engine that detaches gives the activity back to the engine that had it before`() {
        val first = Engine("first")
        val second = Engine("second")

        registry.set(first, "activity of first")
        registry.set(second, "activity of second")
        registry.set(second, null)

        assertEquals("activity of first", registry.current())
    }

    @Test
    fun `an engine that detaches is removed whatever its place`() {
        val first = Engine("first")
        val middle = Engine("middle")
        val last = Engine("last")

        registry.set(first, "activity of first")
        registry.set(middle, "activity of middle")
        registry.set(last, "activity of last")
        registry.set(middle, null)
        assertEquals("activity of last", registry.current())
        registry.set(last, null)
        assertEquals("activity of first", registry.current())
    }

    @Test
    fun `an engine that attaches again becomes the last one with its new activity`() {
        val first = Engine("first")
        val second = Engine("second")

        registry.set(first, "activity of first")
        registry.set(second, "activity of second")
        registry.set(first, null)
        registry.set(first, "recreated activity of first")
        assertEquals("recreated activity of first", registry.current())

        registry.set(second, "recreated activity of second")
        assertEquals("recreated activity of second", registry.current())
        registry.set(second, null)
        assertEquals("recreated activity of first", registry.current())
    }

    @Test
    fun `an engine keeps one activity however many times it attaches`() {
        val engine = Engine("engine")

        registry.set(engine, "first activity")
        registry.set(engine, "second activity")
        assertEquals("second activity", registry.current())
        registry.set(engine, null)

        assertNull(registry.current())
    }

    @Test
    fun `there is no activity once every engine has detached`() {
        val first = Engine("first")
        val second = Engine("second")

        registry.set(first, "activity of first")
        registry.set(second, "activity of second")
        registry.set(first, null)
        registry.set(second, null)

        assertNull(registry.current())
    }

    @Test
    fun `an engine that detaches without having attached changes nothing`() {
        val attached = Engine("attached")

        registry.set(Engine("never attached"), null)
        assertNull(registry.current())
        registry.set(attached, "activity of attached")
        registry.set(Engine("never attached either"), null)

        assertEquals("activity of attached", registry.current())
    }

    @Test
    fun `engines are told apart by identity, not by equality`() {
        data class EqualEngine(val name: String)

        val equalRegistry = ActivityRegistry<EqualEngine, String>()
        val first = EqualEngine("same")
        val second = EqualEngine("same")

        equalRegistry.set(first, "activity of first")
        equalRegistry.set(second, "activity of second")
        equalRegistry.set(second, null)

        assertEquals("activity of first", equalRegistry.current())
    }
}

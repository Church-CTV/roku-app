' Example Rooibos test file
' Tests should use @suite, @test, @setup, @teardown annotations

function suite()
    return "Example Test Suite"
end function

function setup()
    ' Setup code runs before each test
    return
end function

function teardown()
    ' Teardown code runs after each test
    return
end function

@test
function test_example()
    ' Example test
    assert.equal(1 + 1, 2, "1 + 1 should equal 2")
end function

@test
function test_string_operation()
    ' Example string test
    assert.equal("hello".len(), 5, "hello has 5 characters")
end function

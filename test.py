import pytest
from app import add, minus, multi

def test_add():
    assert add(2, 3) == 5
    assert add(-1, 1) == 0
    assert add(0, 0) == 0

def test_minus():
    assert minus(5, 3) == 2
    assert minus(10, 20) == -10
    assert minus(0, 0) == 0

def test_multi():
    assert multi(2, 3) == 6
    assert multi(-2, 3) == -6
    assert multi(0, 100) == 0

"""
Tests for pyvtschooldata Python wrapper.

Minimal smoke tests - the actual data logic is tested by R testthat.
These just verify the Python wrapper imports and exposes expected functions.
"""

import pytest


def test_import_package():
    """Package imports successfully."""
    import pyvtschooldata
    assert pyvtschooldata is not None


def test_has_fetch_enr():
    """fetch_enr function is available."""
    import pyvtschooldata
    assert hasattr(pyvtschooldata, 'fetch_enr')
    assert callable(pyvtschooldata.fetch_enr)


def test_has_get_available_years():
    """get_available_years function is available."""
    import pyvtschooldata
    assert hasattr(pyvtschooldata, 'get_available_years')
    assert callable(pyvtschooldata.get_available_years)


def test_has_version():
    """Package has a version string."""
    import pyvtschooldata
    assert hasattr(pyvtschooldata, '__version__')
    assert isinstance(pyvtschooldata.__version__, str)

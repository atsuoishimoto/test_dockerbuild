from app1.models import Person
import pytest

@pytest.mark.django_db
def test1():
    p = Person(first_name="a", last_name="b")
    p.save()
    1/0
    assert Person.objects.get(first_name="a")

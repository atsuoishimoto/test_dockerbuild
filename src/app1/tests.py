from app1.models import Person

def test1():
    p = Person(first_name="a", last_name="b")
    p.save()

    assert Person.objects.get(first_name="a")
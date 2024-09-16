from .settings import *
DATABASES = {
   'default': {
       'ENGINE': 'django.db.backends.mysql',
       'NAME': os.environ['MYSQL_DATABASE'],
       'USER': os.environ['MYSQL_USER'],
       'PASSWORD': os.environ['MYSQL_PASSWORD'],
       'HOST': os.environ['MYSQL_HOST'],
   },
}

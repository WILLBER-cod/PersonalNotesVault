from django.urls import path
from .views import register, login, UserProfileView

urlpatterns = [
    path('register/', register, name='register'),
    path('login/', login, name='login'),
    path('profile/', UserProfileView.as_view(), name='profile'),
]




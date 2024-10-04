from pydantic import BaseModel


class UserBase(BaseModel):
    username: str
    fullname: str
    email: str
    password: str


class UserCreate(UserBase):
    pass

class UserUpdate(UserBase):
    pass

class User(UserBase):
    id: int


class TokenData(BaseModel):
    username: str | None = None


class Token(BaseModel):
    access_token: str
    token_type: str
    user: User

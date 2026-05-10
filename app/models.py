from pydantic import BaseModel, EmailStr


class Token(BaseModel):
    access_token: str
    token_type: str


class TokenData(BaseModel):
    username: str | None = None


class UserOut(BaseModel):
    username: str
    email: str


class ItemOut(BaseModel):
    item_id: int
    name: str
    owner: str

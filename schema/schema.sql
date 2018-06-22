CREATE TABLE shortcut (
    id SERIAL NOT NULL,
    created_at TIMESTAMP DEFAULT current_timestamp NOT NULL,
    name TEXT NOT NULL UNIQUE,
    owner TEXT NOT NULL,
    url TEXT NOT NULL,
    secondary_url TEXT,
    hits INT NOT NULL
);

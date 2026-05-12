CREATE DATABASE ss15_social_network_db;
USE ss15_social_network_db;

-- 1. TABLE USERS

CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);


-- 2. TABLE POSTS

CREATE TABLE posts (
    post_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    content TEXT NOT NULL,

    like_count INT DEFAULT 0,
    comment_count INT DEFAULT 0,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_posts_users
    FOREIGN KEY (user_id)
    REFERENCES users(user_id)
);

-- FULLTEXT SEARCH

ALTER TABLE posts
ADD FULLTEXT(content);

-- 3. TABLE COMMENTS

CREATE TABLE comments (
    comment_id INT PRIMARY KEY AUTO_INCREMENT,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    content TEXT NOT NULL,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_comments_posts
    FOREIGN KEY (post_id)
    REFERENCES posts(post_id),

    CONSTRAINT fk_comments_users
    FOREIGN KEY (user_id)
    REFERENCES users(user_id)
);


-- 4. TABLE LIKES

CREATE TABLE likes (
    like_id INT PRIMARY KEY AUTO_INCREMENT,

    user_id INT NOT NULL,
    post_id INT NOT NULL,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_user_post
    UNIQUE(user_id, post_id),

    CONSTRAINT fk_likes_users
    FOREIGN KEY (user_id)
    REFERENCES users(user_id),

    CONSTRAINT fk_likes_posts
    FOREIGN KEY (post_id)
    REFERENCES posts(post_id)
);


-- 5. TABLE FRIENDS

CREATE TABLE friends (
    friendship_id INT PRIMARY KEY AUTO_INCREMENT,

    user_id INT NOT NULL,
    friend_id INT NOT NULL,

    status VARCHAR(20)
    CHECK(status IN ('pending', 'accepted')),

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_not_self_friend
    CHECK(user_id <> friend_id),

    CONSTRAINT fk_friends_user
    FOREIGN KEY (user_id)
    REFERENCES users(user_id),

    CONSTRAINT fk_friends_friend
    FOREIGN KEY (friend_id)
    REFERENCES users(user_id)
);


-- 6. TABLE POST LOGS

CREATE TABLE post_logs (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    post_id INT,
    post_content TEXT,
    deleted_at DATETIME DEFAULT CURRENT_TIMESTAMP
);


INSERT INTO users(username, password, email)
VALUES
('alice', '123456', 'alice@gmail.com'),
('bob', '123456', 'bob@gmail.com'),
('charlie', '123456', 'charlie@gmail.com');


INSERT INTO posts(user_id, content)
VALUES
(1, 'Hello everyone'),
(2, 'Learning MySQL'),
(3, 'Social network project');


INSERT INTO comments(post_id, user_id, content)
VALUES
(1, 2, 'Nice post'),
(1, 3, 'Very good');


INSERT INTO likes(user_id, post_id)
VALUES
(1, 2),
(2, 1),
(3, 1);

INSERT INTO friends(user_id, friend_id, status)
VALUES
(1, 2, 'accepted'),
(1, 3, 'pending');

create view view_user_info as 
select user_id, username, email, created_at 
where users;

delimiter //
create procedure sp_add_user (
	in p_username varchar(50),
    in p_password varchar(25),
    in p_email varchar(100)
)
begin 
	declare check_username int;
    declare check_email int;
	select count(*) into check_username 
    from users 
    where username = p_username;
	
    select count(*) into check_email
    from email
    where email = p_email;
    
    if check_username > 0 then 
		signal sqlstate '45000'
        set message_text = 'Username đã tồn tại';
	elseif 
		check_email > 0 then 
			signal sqlstate '45000'
            set message_text = 'email đã tồn tại';
	else	
		insert into users(username, password, email)
        values (p_username, p_password, p_email);
	end if;
end //
delimiter ;

call sp_add_user('','','');

-- 3
-- Tăng Like 
delimiter // 
create trigger tg_after_like_insert 

after insert on likes 

for each row 

begin 
	update posts 
    set like_count = like_count + 1
    where post_id = new.post_id; 
    
end // 
delimiter ;

-- Trừ comment
delimiter // 
create trigger tg_after_comment_insert 

after insert on comments 

for each row 

begin 
    update posts 
    set comment_count = comment_count + 1
    where post_id = new.post_id;
end // 
delimiter ;

-- Xóa
-- Trừ Like
delimiter // 
create trigger tg_after_like_delete

after insert on likes 

for each row 

begin 
	update posts 
    set like_count = 
		case 
			when like_count > 0 then
				like_count + 1
			else 0
		end
    where post_id = old.post_id; 
end // 
delimiter ;

-- Trừ comment 
delimiter // 
create trigger tg_after_comment_delete

after insert on comments

for each row 

begin 
    update posts 
    set comment_count = 
		case 
			when comment_count > 0 then
				comment_count + 1
			else 0
		end
    where post_id = old.post_id;
end // 
delimiter ;

-- 4
DELIMITER //
create procedure sp_user_activity_report()

begin
    select
        u.user_id,
        u.username,
        COUNT(distinct p.post_id) as total_posts,
        COUNT(distinct l.like_id) as total_likes,
        COUNT(distinct c.comment_id) as total_comments
    from users u
    left join posts p on u.user_id = p.user_id
    left join likes l on u.user_id = l.user_id
    left join comments c on u.user_id = c.user_id
    group by u.user_id, u.username;
end //
DELIMITER ;

-- 5
DELIMITER //

create procedure sp_delete_user(
    in p_user_id int,
    out p_status_message varchar(255)
)
begin
    declare v_user_exists int default 0;

    start transaction;

    select count(*) into v_user_exists 
    from users 
    where user_id = p_user_id;

    if v_user_exists = 0 then
        rollback;
        set p_status_message = 'LỖI: Người dùng không tồn tại!';
    else
        delete from likes where user_id = p_user_id;
        delete from comments where user_id = p_user_id;
        delete from friends where user_id = p_user_id or friend_id = p_user_id;
        delete from posts where user_id = p_user_id;
        delete from users where user_id = p_user_id;

        commit;
        set p_status_message = 'THÀNH CÔNG: Đã xóa tài khoản và mọi dữ liệu liên quan!';
    end if;

end //

DELIMITER ;

call sp_delete_user (2, @msg);

-- 6
DELIMITER //

create trigger tg_before_friend_insert

before insert on friends

for each row

begin
    declare v_exists int default 0;

    if new.user_id = new.friend_id then
        set new.user_id = null; 
    else 
        select count(*) into v_exists
        from friends
        where (user_id = new.user_id and friend_id = new.friend_id)
		or (user_id = new.friend_id and friend_id = new.user_id);

        if v_exists > 0 then
            set new.user_id = null;
        end if;
    end if;

end //
export interface User {
 id: number;
 username: string;
 email: string;
 bio?: string;
 avatarUrl?: string;
 createdAt: string;
 postCount: number;
 followerCount: number;
 followingCount: number;
}

export interface Post {
 id: number;
 content: string;
 createdAt: string;
 author: User;
 likeCount: number;
 isLikedByMe: boolean;
}

export interface FeedResponse {
 posts: Post[];
 totalCount: number;
 page: number;
 pageSize: number;
}

export interface AuthResponse {
 token: string;
 user: User;
}

export interface LoginRequest {
 email: string;
 password: string;
}

export interface RegisterRequest {
 username: string;
 email: string;
 password: string;
}

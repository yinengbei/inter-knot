export const typeDefs = `#graphql
  type User {
    id: Int!
    username: String!
    email: String!
    avatarUrl: String
    createdAt: String!
  }

  type Discussion {
    id: Int!
    title: String!
    bodyHTML: String!
    bodyText: String!
    cover: String
    createdAt: String!
    updatedAt: String!
    author: User!
    comments(first: Int, after: String): CommentConnection!
    commentsCount: Int!
    number: Int! # Alias for id to match frontend
  }

  type Comment {
    id: Int!
    bodyHTML: String!
    createdAt: String!
    updatedAt: String!
    author: User!
    discussion: Discussion!
  }

  type CommentConnection {
    nodes: [Comment!]!
    pageInfo: PageInfo!
    totalCount: Int!
  }

  type DiscussionConnection {
    nodes: [Discussion!]!
    pageInfo: PageInfo!
    totalCount: Int!
  }

  type PageInfo {
    endCursor: String
    hasNextPage: Boolean!
  }

  type AuthPayload {
    token: String!
    user: User!
  }

  type Query {
    search(query: String!, first: Int, after: String): DiscussionConnection!
    getDiscussion(number: Int!): Discussion
    me: User
  }

  type Mutation {
    login(email: String!, password: String!): AuthPayload
    register(username: String!, email: String!, password: String!): AuthPayload
    createDiscussion(title: String!, bodyHTML: String!, bodyText: String!, cover: String): Discussion!
    addComment(discussionId: Int!, bodyHTML: String!): Comment!
  }
`;



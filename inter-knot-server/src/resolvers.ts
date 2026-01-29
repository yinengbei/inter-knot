import { Context, APP_SECRET } from './context';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

export const resolvers = {
  Query: {
    me: (_parent: any, _args: any, context: Context) => {
      if (!context.userId) return null;
      return context.prisma.user.findUnique({ where: { id: context.userId } });
    },
    getDiscussion: async (_parent: any, args: { number: number }, context: Context) => {
      return context.prisma.discussion.findUnique({
        where: { id: args.number },
        include: { author: true },
      });
    },
    search: async (_parent: any, args: { query: string; first?: number; after?: string }, context: Context) => {
      const take = args.first || 20;
      const skip = args.after ? 1 : 0;
      const cursor = args.after ? { id: parseInt(args.after) } : undefined;

      const where = args.query
        ? {
            OR: [
              { title: { contains: args.query } },
              { bodyText: { contains: args.query } },
            ],
          }
        : {};

      const discussions = await context.prisma.discussion.findMany({
        where,
        take: take + 1, // Get one extra to check hasNextPage
        skip,
        cursor,
        orderBy: { createdAt: 'desc' },
        include: { author: true },
      });

      const hasNextPage = discussions.length > take;
      if (hasNextPage) {
        discussions.pop();
      }

      return {
        nodes: discussions,
        pageInfo: {
          endCursor: discussions.length > 0 ? discussions[discussions.length - 1].id.toString() : null,
          hasNextPage,
        },
        totalCount: await context.prisma.discussion.count({ where }),
      };
    },
  },
  Mutation: {
    register: async (_parent: any, args: { username: string; email: string; password: string }, context: Context) => {
      const password = await bcrypt.hash(args.password, 10);
      const user = await context.prisma.user.create({
        data: { ...args, password },
      });
      const token = jwt.sign({ userId: user.id }, APP_SECRET);
      return { token, user };
    },
    login: async (_parent: any, args: { email: string; password: string }, context: Context) => {
      const user = await context.prisma.user.findUnique({ where: { email: args.email } });
      if (!user) throw new Error('No such user found');

      const valid = await bcrypt.compare(args.password, user.password);
      if (!valid) throw new Error('Invalid password');

      const token = jwt.sign({ userId: user.id }, APP_SECRET);
      return { token, user };
    },
    createDiscussion: async (_parent: any, args: { title: string; bodyHTML: string; bodyText: string; cover?: string }, context: Context) => {
      console.log('createDiscussion called', { userId: context.userId, args });
      if (!context.userId) throw new Error('Not authenticated');
      return context.prisma.discussion.create({
        data: {
          title: args.title,
          bodyHTML: args.bodyHTML,
          bodyText: args.bodyText,
          cover: args.cover,
          author: { connect: { id: context.userId } },
        },
        include: { author: true },
      });
    },
    addComment: async (_parent: any, args: { discussionId: number; bodyHTML: string }, context: Context) => {
      if (!context.userId) throw new Error('Not authenticated');
      return context.prisma.comment.create({
        data: {
          bodyHTML: args.bodyHTML,
          discussion: { connect: { id: args.discussionId } },
          author: { connect: { id: context.userId } },
        },
        include: { author: true, discussion: true },
      });
    },
  },
  Discussion: {
    number: (parent: any) => parent.id,
    createdAt: (parent: any) => new Date(parent.createdAt).toISOString(),
    updatedAt: (parent: any) => new Date(parent.updatedAt).toISOString(),
    commentsCount: (parent: any, _args: any, context: Context) => {
      return context.prisma.comment.count({ where: { discussionId: parent.id } });
    },
    comments: async (parent: any, args: { first?: number; after?: string }, context: Context) => {
      const take = args.first || 20;
      const skip = args.after ? 1 : 0;
      const cursor = args.after ? { id: parseInt(args.after) } : undefined;

      const comments = await context.prisma.comment.findMany({
        where: { discussionId: parent.id },
        take: take + 1,
        skip,
        cursor,
        orderBy: { createdAt: 'asc' }, // Comments typically ascending
        include: { author: true },
      });

      const hasNextPage = comments.length > take;
      if (hasNextPage) {
        comments.pop();
      }

      return {
        nodes: comments,
        pageInfo: {
          endCursor: comments.length > 0 ? comments[comments.length - 1].id.toString() : null,
          hasNextPage,
        },
        totalCount: await context.prisma.comment.count({ where: { discussionId: parent.id } }),
      };
    },
  },
  Comment: {
    createdAt: (parent: any) => new Date(parent.createdAt).toISOString(),
    updatedAt: (parent: any) => new Date(parent.updatedAt).toISOString(),
    discussion: (parent: any, _args: any, context: Context) => {
        // Optimisation: if parent.discussion is loaded use it, otherwise fetch
        if (parent.discussion) return parent.discussion;
        return context.prisma.discussion.findUnique({ where: { id: parent.discussionId } });
    },
    author: (parent: any, _args: any, context: Context) => {
        if (parent.author) return parent.author;
        return context.prisma.user.findUnique({ where: { id: parent.authorId } });
    }
  },
  User: {
      // Date to ISO string
      createdAt: (parent: any) => new Date(parent.createdAt).toISOString(),
  }
};



import { CardFactory, TestAdapter } from "botbuilder";
import { describe, expect, it } from "vitest";
import { TeamsBot } from "./bot";

/**
 * Sends messages to the bot through TestAdapter and asserts the replies.
 * When a template is given, it is merged into every activity that is sent.
 */
const createAdapter = (template?: ConstructorParameters<typeof TestAdapter>[1]) => {
  const bot = new TeamsBot();
  return new TestAdapter(async (context) => bot.run(context), template);
};

describe("TeamsBot", () => {
  it("replies to hello with a greeting that includes the sender name", async () => {
    await createAdapter().send("hello").assertReply("Hello, User1!");
  });

  it("replies to help with a help card", async () => {
    await createAdapter()
      .send("ヘルプ")
      .assertReply((activity) => {
        expect(activity.attachments?.[0]?.contentType).toBe(CardFactory.contentTypes.adaptiveCard);
      });
  });

  it("echoes back unknown messages", async () => {
    await createAdapter().send("foo").assertReply('Received message: "foo"');
  });

  it("replies only with guidance in personal chats", async () => {
    await createAdapter({
      conversation: {
        id: "personal-1",
        name: "personal-1",
        isGroup: false,
        conversationType: "personal",
      },
    })
      .send("hello")
      .assertReply(
        "This bot is not available in personal chats. Please add it to a team channel or a group chat.",
      );
  });
});

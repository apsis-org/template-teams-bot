import { CardFactory, TestAdapter } from "botbuilder";
import { describe, expect, it } from "vitest";
import { TeamsBot } from "./bot";

/**
 * TestAdapter でボットにメッセージを送り、応答を検証する。
 * template を渡すと、送信する全アクティビティにその値が上書きマージされる。
 */
const createAdapter = (template?: ConstructorParameters<typeof TestAdapter>[1]) => {
  const bot = new TeamsBot();
  return new TestAdapter(async (context) => bot.run(context), template);
};

describe("TeamsBot", () => {
  it("hello に送信者名入りの挨拶を返す", async () => {
    await createAdapter().send("hello").assertReply("こんにちは、User1 さん！");
  });

  it("help でヘルプカードを返す", async () => {
    await createAdapter()
      .send("ヘルプ")
      .assertReply((activity) => {
        expect(activity.attachments?.[0]?.contentType).toBe(CardFactory.contentTypes.adaptiveCard);
      });
  });

  it("未知のメッセージはエコーバックする", async () => {
    await createAdapter().send("foo").assertReply('受け取ったメッセージ: "foo"');
  });

  it("個人チャットでは案内メッセージだけを返す", async () => {
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
        "このBotは個人チャットではご利用いただけません。チームのチャネルまたはグループチャットに追加してご利用ください。",
      );
  });
});

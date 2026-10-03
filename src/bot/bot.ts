import {
  ActivityHandler,
  MessageFactory,
  TurnContext,
  TeamsActivityHandler,
  CardFactory,
} from "botbuilder";

/**
 * TeamsBot - Microsoft Teams Bot のメインクラス
 *
 * TeamsActivityHandler を継承し、Teams 固有のイベントを処理します。
 * 汎用ボットとして利用する場合は ActivityHandler に変更してください。
 */
export class TeamsBot extends TeamsActivityHandler {
  constructor() {
    super();

    // メッセージを受信したときの処理
    this.onMessage(async (context: TurnContext, next) => {
      if (context.activity.conversation.conversationType === "personal") {
        await context.sendActivity(
          MessageFactory.text(
            "このBotは個人チャットではご利用いただけません。チームのチャネルまたはグループチャットに追加してご利用ください。"
          )
        );
        await next();
        return;
      }

      const text = context.activity.text?.trim() ?? "";

      console.log(`Received message: ${text}`);

      if (text.toLowerCase() === "help" || text === "ヘルプ") {
        await this.sendHelpCard(context);
      } else if (text.toLowerCase() === "hello" || text === "こんにちは") {
        await context.sendActivity(
          MessageFactory.text(`こんにちは、${context.activity.from.name} さん！`)
        );
      } else {
        // デフォルト応答: エコーバック
        await context.sendActivity(MessageFactory.text(`受け取ったメッセージ: "${text}"`));
      }

      await next();
    });

    // メンバーが会話に追加されたときの処理
    this.onMembersAdded(async (context: TurnContext, next) => {
      if (context.activity.conversation.conversationType === "personal") {
        await next();
        return;
      }

      const membersAdded = context.activity.membersAdded ?? [];

      for (const member of membersAdded) {
        if (member.id !== context.activity.recipient.id) {
          try {
            const name = member.name ?? "ゲスト";
            await context.sendActivity(
              MessageFactory.text(
                `ようこそ、${name} さん！\n\n「help」または「ヘルプ」と入力すると使い方を確認できます。`
              )
            );
          } catch (error) {
            console.warn("Failed to send welcome message:", (error as Error).message);
          }
        }
      }

      await next();
    });
  }

  private async sendHelpCard(context: TurnContext): Promise<void> {
    const helpCard = CardFactory.adaptiveCard({
      type: "AdaptiveCard",
      version: "1.5",
      body: [
        {
          type: "TextBlock",
          size: "Medium",
          weight: "Bolder",
          text: "Teams Bot ヘルプ",
        },
        {
          type: "TextBlock",
          text: "以下のコマンドが使用できます：",
          wrap: true,
        },
        {
          type: "FactSet",
          facts: [
            { title: "hello / こんにちは", value: "挨拶に応答します" },
            { title: "help / ヘルプ", value: "このヘルプカードを表示します" },
          ],
        },
      ],
    });

    await context.sendActivity(MessageFactory.attachment(helpCard));
  }
}

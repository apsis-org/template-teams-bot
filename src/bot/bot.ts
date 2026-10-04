import { MessageFactory, TurnContext, TeamsActivityHandler, CardFactory } from "botbuilder";

/**
 * TeamsBot - main class of the Microsoft Teams bot
 *
 * Extends TeamsActivityHandler to handle Teams-specific events.
 * Switch to ActivityHandler if you want a channel-agnostic bot.
 */
export class TeamsBot extends TeamsActivityHandler {
  constructor() {
    super();

    // Handle incoming messages
    this.onMessage(async (context: TurnContext, next) => {
      if (context.activity.conversation.conversationType === "personal") {
        await context.sendActivity(
          MessageFactory.text(
            "This bot is not available in personal chats. Please add it to a team channel or a group chat.",
          ),
        );
        await next();
        return;
      }

      const text = context.activity.text?.trim() ?? "";

      console.log(`Received message: ${text}`);

      if (text.toLowerCase() === "help" || text === "ヘルプ") {
        await this.sendHelpCard(context);
      } else if (text.toLowerCase() === "hello" || text === "こんにちは") {
        await context.sendActivity(MessageFactory.text(`Hello, ${context.activity.from.name}!`));
      } else {
        // Default reply: echo back
        await context.sendActivity(MessageFactory.text(`Received message: "${text}"`));
      }

      await next();
    });

    // Handle members being added to the conversation
    this.onMembersAdded(async (context: TurnContext, next) => {
      if (context.activity.conversation.conversationType === "personal") {
        await next();
        return;
      }

      const membersAdded = context.activity.membersAdded ?? [];

      for (const member of membersAdded) {
        if (member.id !== context.activity.recipient.id) {
          try {
            const name = member.name ?? "there";
            await context.sendActivity(
              MessageFactory.text(`Welcome, ${name}!\n\nType "help" to see how to use this bot.`),
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
          text: "Teams Bot Help",
        },
        {
          type: "TextBlock",
          text: "The following commands are available:",
          wrap: true,
        },
        {
          type: "FactSet",
          facts: [
            { title: "hello / こんにちは", value: "Replies with a greeting" },
            { title: "help / ヘルプ", value: "Shows this help card" },
          ],
        },
      ],
    });

    await context.sendActivity(MessageFactory.attachment(helpCard));
  }
}

import {
	app,
	type HttpRequest,
	type HttpResponseInit,
	type InvocationContext,
} from "@azure/functions";
import type { Request, Response } from "botbuilder";
import { adapter } from "../bot/adapter";
import { TeamsBot } from "../bot/bot";

const bot = new TeamsBot();

/**
 * Bot Framework の Request インターフェースに準拠した
 * Azure Functions HttpRequest のアダプター
 */
class AzureFunctionsRequestAdapter implements Request {
	body: Record<string, unknown> | undefined;
	headers: Record<string, string | string[] | undefined>;
	method: string;

	constructor(req: HttpRequest, body: string) {
		try {
			this.body = JSON.parse(body) as Record<string, unknown>;
		} catch {
			this.body = undefined;
		}
		this.headers = {};
		req.headers.forEach((value, key) => {
			this.headers[key.toLowerCase()] = value;
		});
		this.method = "POST";
	}
}

/**
 * Bot Framework の Response インターフェースに準拠した
 * Azure Functions HttpResponse のアダプター
 */
class AzureFunctionsResponseAdapter implements Response {
	socket: unknown = null;
	private _status: number = 200;
	private _body: string = "";
	private _headers: Record<string, string> = {};

	status(code: number): unknown {
		this._status = code;
		return this;
	}

	send(...args: unknown[]): unknown {
		const body = args[0];
		if (body !== undefined) {
			this._body = typeof body === "string" ? body : JSON.stringify(body);
		}
		return this;
	}

	end(...args: unknown[]): unknown {
		return this.send(...args);
	}

	header(name: string, value: unknown): unknown {
		this._headers[name] = String(value);
		return this;
	}

	toHttpResponseInit(): HttpResponseInit {
		return {
			status: this._status,
			body: this._body,
			headers: this._headers,
		};
	}
}

/**
 * Azure Functions HTTP トリガー - Teams Bot のメッセージエンドポイント
 * Bot Framework からのアクティビティを受信し、ボットロジックに渡します
 */
app.http("messages", {
	methods: ["POST"],
	authLevel: "anonymous",
	route: "messages",
	handler: async (
		req: HttpRequest,
		context: InvocationContext,
	): Promise<HttpResponseInit> => {
		context.log("Teams Bot: Processing incoming activity");

		const body = await req.text();
		const request = new AzureFunctionsRequestAdapter(req, body);
		const response = new AzureFunctionsResponseAdapter();

		try {
			await adapter.process(request, response, async (turnContext) => {
				await bot.run(turnContext);
			});
		} catch (error) {
			context.error("Error processing activity:", error);
			return { status: 500, body: "Internal Server Error" };
		}

		return response.toHttpResponseInit();
	},
});

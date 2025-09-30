# Colonne aggiuntive rispetto allo schema ruby_llm

## Colonne aggiuntive in `chats` rispetto a ruby_llm:

1. **`user_id`** (bigint, not null) - Associazione con gli utenti della tua applicazione

## Colonne aggiuntive in `messages` rispetto a ruby_llm:

1. **`chat_id`** (bigint) - per associare i messaggi alle chat (ruby_llm non prevede questa relazione diretta)
2. **`response_number`** (integer, default: 0, not null) - per tracciare il numero di risposta

## Schema ruby_llm standard

Lo schema ruby_llm prevede una struttura più semplice dove:

### Tabella `chats`:
- `id` (BIGSERIAL PRIMARY KEY)
- `model_id` (BIGINT)
- `created_at` (TIMESTAMP NOT NULL)
- `updated_at` (TIMESTAMP NOT NULL)

### Tabella `messages`:
- `id` (BIGSERIAL PRIMARY KEY)
- `chat_id` (BIGINT NOT NULL)
- `role` (VARCHAR NOT NULL)
- `content` (TEXT)
- `input_tokens` (INTEGER)
- `output_tokens` (INTEGER)
- `model_id` (BIGINT)
- `tool_call_id` (BIGINT)
- `created_at` (TIMESTAMP NOT NULL)
- `updated_at` (TIMESTAMP NOT NULL)

## Conclusione

Le colonne aggiuntive (`user_id` in chats e `response_number` in messages) sono specifiche per la tua applicazione e non fanno parte dello schema base ruby_llm.
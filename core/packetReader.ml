(*
 * Copyright (C) Citrix Systems Inc.
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)
open Lwt

module Make(Reader: S.WINDOW
  with type offset = int64
  and  type item = Cstruct.t) = struct
  type t = Reader.t
  type item = [ `Ok of (Protocol.Header.t * Protocol.Request.t) | `Error of string ]
  type offset = Reader.offset

  let rec next t =
    Reader.next t >>= fun (offset, space) ->
    let len = Cstruct.len space in
    if len < Protocol.Header.sizeof
    then next t
    else begin
      match Protocol.Header.unmarshal space with
      | `Error x -> return (offset, `Error x)
      | `Ok x ->
        let rec loop () =
          Reader.next t >>= fun (offset, space) ->
          let length = Protocol.Header.sizeof + x.Protocol.Header.len in
          let len = Cstruct.len space in
          if len < length
          then loop ()
          else begin
            let payload = Cstruct.sub space Protocol.Header.sizeof x.Protocol.Header.len in
            let offset = Int64.(add offset (of_int length)) in
            match Protocol.Request.unmarshal x payload with
            | `Ok y -> return (offset, `Ok (x, y))
            | `Error y -> return (offset, `Error y)
          end in
        loop ()
    end

  let ack t ofs =
    Reader.ack t ofs
end
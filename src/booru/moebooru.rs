// Engine for Moebooru sites (konachan, yande.re). Port of hoshi's moebooru.rs
use super::*;

// konachan.com's API is behind a Cloudflare challenge: the browser's cf_clearance cookie only
// passes together with the User-Agent of the browser that solved it. Images aren't challenged
pub const COOKIE_FIELDS: &[Field] = &[
    Field { key: "cookie", label: "Cookie", secret: true },
    Field { key: "user_agent", label: "User-Agent", secret: false },
];

pub struct Moebooru {
    pub id: &'static str,
    pub name: &'static str,
    pub base: &'static str,
    // Drop anything not rated safe, even in spicy mode: konachan.net is the SFW mirror
    pub safe_only: bool,
    pub account: Option<Account>,
}

impl Moebooru {
    fn fetch(&self, tags: &str, page: u32, limit: u32, auth: &Credentials) -> Result<Vec<Value>, String> {
        require(self.name, self.account.as_ref(), auth)?;
        let mut request = get(&format!("{}/post.json", self.base))
            .query("tags", tags)
            .query("page", page.to_string())
            .query("limit", limit.to_string());
        if let Some(cookie) = cred(auth, "cookie") {
            // A bare value (what the browser's cookie panel shows) is the cf_clearance cookie
            let cookie = if cookie.contains('=') { cookie.to_owned() } else { format!("cf_clearance={cookie}") };
            request = request.header("Cookie", cookie);
        }
        if let Some(ua) = cred(auth, "user_agent") {
            request = request.header("User-Agent", ua);
        }
        let raw = send_json(self.id, request)?;
        match raw {
            Value::Array(posts) => Ok(posts),
            _ => Err(format!("{}: expected a list of posts", self.id)),
        }
    }

    fn map(&self, v: &Value) -> Option<Post> {
        let id = u64_of(v, "id");
        let ext = str_of(v, "file_ext");
        let keep = id > 0 && is_image(&ext) && (!self.safe_only || str_of(v, "rating") == "s");
        keep.then(|| Post {
            source: self.id,
            id,
            width: u64_of(v, "width"),
            height: u64_of(v, "height"),
            score: i64_of(v, "score"),
            rating: str_of(v, "rating"),
            tags: str_of(v, "tags"),
            ext,
            size: u64_of(v, "file_size"),
            preview: str_of(v, "preview_url"),
            sample: str_of(v, "sample_url"),
            file: str_of(v, "file_url"),
            url: format!("{}/post/show/{id}", self.base),
        })
    }
}

impl Source for Moebooru {
    fn id(&self) -> &'static str {
        self.id
    }

    fn name(&self) -> &'static str {
        self.name
    }

    fn base(&self) -> &'static str {
        self.base
    }

    fn account(&self) -> Option<&Account> {
        self.account.as_ref()
    }

    fn search(&self, q: &Query) -> Result<Page, String> {
        let limit = q.limit.clamp(1, 100);
        let sort = match q.sort {
            Sort::Latest => "",
            Sort::Score => "order:score",
            Sort::Random => "order:random",
        };
        let rating = if q.spicy { "" } else { "rating:s" };
        let raw = self.fetch(&join_tags(&[q.tags, sort, rating]), q.page.max(1), limit, q.auth)?;
        Ok(Page {
            more: raw.len() as u32 == limit,
            posts: raw.iter().filter_map(|v| self.map(v)).filter(|p| q.allows(&p.rating)).collect(),
        })
    }

    fn post(&self, id: u64, auth: &Credentials) -> Result<Post, String> {
        self.fetch(&format!("id:{id}"), 1, 1, auth)?
            .iter()
            .find_map(|v| self.map(v))
            .ok_or_else(|| format!("{} post {id} not found", self.id))
    }
}

#[cfg(test)]
mod tests {
    use super::super::sources::KONACHAN_NET;

    #[test]
    fn maps_and_filters_posts() {
        let raw = serde_json::json!([
            {"id": 42, "rating": "s", "tags": "sky clouds", "file_ext": "png", "width": 1920,
             "height": 1080, "score": 7, "file_url": "https://konachan.net/image/a.png"},
            {"id": 43, "rating": "q", "file_ext": "png"},
            {"id": 44, "rating": "s", "file_ext": "gif"},
            {"rating": "s", "file_ext": "png"}
        ]);
        let posts: Vec<_> = raw.as_array().unwrap().iter().filter_map(|v| KONACHAN_NET.map(v)).collect();
        assert_eq!(posts.len(), 1);
        assert_eq!((posts[0].id, posts[0].width, posts[0].score), (42, 1920, 7));
        assert_eq!(posts[0].url, "https://konachan.net/post/show/42");
    }
}

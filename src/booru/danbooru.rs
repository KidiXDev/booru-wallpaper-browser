// Engine for Danbooru-API sites. Port of hoshi's danbooru.rs (search/post only).
// Searches are limited to 2 tags (6 for Gold accounts), and order: counts as one but rating:
// doesn't; the API's message is passed through
use super::*;

pub const FIELDS: &[Field] = &[
    Field { key: "login", label: "Username", secret: false },
    Field { key: "api_key", label: "API key", secret: true },
];

pub struct Danbooru {
    pub id: &'static str,
    pub name: &'static str,
    pub base: &'static str,
    pub account: Option<Account>,
}

impl Danbooru {
    fn get(&self, path: &str, auth: &Credentials) -> ureq::RequestBuilder<ureq::typestate::WithoutBody> {
        let request = get(&format!("{}{path}", self.base));
        match (cred(auth, "login"), cred(auth, "api_key")) {
            (Some(login), Some(key)) => request.query("login", login).query("api_key", key),
            _ => request,
        }
    }

    fn map(&self, v: &Value) -> Option<Post> {
        let id = u64_of(v, "id");
        let ext = str_of(v, "file_ext");
        // Restricted posts come without file_url
        let file = str_of(v, "file_url");
        if id == 0 || file.is_empty() || !is_image(&ext) {
            return None;
        }
        // 720x720 is a fit-within variant, sharp enough for the grid
        let variant = |kind: &str| {
            v.pointer("/media_asset/variants")?
                .as_array()?
                .iter()
                .find(|x| x.get("type").and_then(Value::as_str) == Some(kind))
                .map(|x| str_of(x, "url"))
        };
        let preview = variant("720x720").unwrap_or_else(|| str_of(v, "preview_file_url"));
        let sample = Some(str_of(v, "large_file_url")).filter(|s| !s.is_empty()).unwrap_or_else(|| file.clone());
        Some(Post {
            source: self.id,
            id,
            width: u64_of(v, "image_width"),
            height: u64_of(v, "image_height"),
            score: i64_of(v, "score"),
            rating: str_of(v, "rating"),
            tags: str_of(v, "tag_string"),
            ext,
            size: u64_of(v, "file_size"),
            preview,
            sample,
            file,
            url: format!("{}/posts/{id}", self.base),
        })
    }
}

impl Source for Danbooru {
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
        let limit = q.limit.clamp(1, 200);
        let sort = match q.sort {
            Sort::Latest => "",
            // Scoring every post times out on danbooru.donmai.us; rank is recent posts by score
            Sort::Score if q.tags.trim().is_empty() => "order:rank",
            Sort::Score => "order:score",
            Sort::Random => "order:random",
        };
        let rating = if q.spicy { "" } else { "rating:g,s" };
        let raw = send_json(
            self.id,
            self.get("/posts.json", q.auth)
                .query("tags", join_tags(&[q.tags, sort, rating]))
                .query("page", q.page.max(1).to_string())
                .query("limit", limit.to_string()),
        )?;
        let raw = raw.as_array().ok_or_else(|| format!("{}: expected a list of posts", self.id))?;
        Ok(Page {
            more: raw.len() as u32 == limit,
            posts: raw.iter().filter_map(|v| self.map(v)).filter(|p| q.allows(&p.rating)).collect(),
        })
    }

    fn post(&self, id: u64, auth: &Credentials) -> Result<Post, String> {
        let raw = send_json(self.id, self.get(&format!("/posts/{id}.json"), auth))?;
        self.map(&raw).ok_or_else(|| format!("{} post {id} has no downloadable image", self.id))
    }
}

#[cfg(test)]
mod tests {
    use super::super::sources::DANBOORU_SAFE;

    #[test]
    fn maps_posts() {
        let raw = serde_json::json!({
            "id": 7, "image_width": 2048, "image_height": 1595, "score": 3, "rating": "g",
            "file_ext": "jpg", "file_size": 427782, "tag_string": "scenery sky",
            "file_url": "https://cdn.donmai.us/original/a.jpg",
            "large_file_url": "https://cdn.donmai.us/sample/a.jpg",
            "preview_file_url": "https://cdn.donmai.us/180x180/a.jpg",
            "media_asset": {"variants": [
                {"type": "180x180", "url": "https://cdn.donmai.us/180x180/a.jpg"},
                {"type": "720x720", "url": "https://cdn.donmai.us/720x720/a.webp"}
            ]}
        });
        let post = DANBOORU_SAFE.map(&raw).unwrap();
        assert_eq!(post.preview, "https://cdn.donmai.us/720x720/a.webp");
        assert_eq!(post.sample, "https://cdn.donmai.us/sample/a.jpg");
        assert_eq!((post.width, post.size), (2048, 427782));
        assert!(DANBOORU_SAFE.map(&serde_json::json!({"id": 8, "file_ext": "jpg"})).is_none());
        assert!(DANBOORU_SAFE.map(&serde_json::json!({"id": 9, "file_ext": "mp4", "file_url": "x.mp4"})).is_none());
    }
}

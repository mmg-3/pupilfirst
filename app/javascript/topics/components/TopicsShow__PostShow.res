open TopicsShow__Types

let str = React.string
%bs.raw(`require("./TopicsShow__PostShow.css")`)

let solutionIcon =
  <div
    ariaLabel="Marked as solution icon"
    className="flex lg:flex-col items-center px-2 lg:pl-0 py-1 lg:pr-4 lg:pb-4 lg:pt-2 bg-green-200 lg:bg-transparent rounded">
    <div
      className="flex items-center justify-center lg:w-8 lg:h-8 bg-green-200 text-green-800 rounded-full">
      <PfIcon className="if i-check-solid text-sm lg:text-base" />
    </div>
    <div className="text-xs lg:text-tiny font-semibold text-green-800 pl-2 lg:pl-0 lg:pt-1">
      {"Solution" |> str}
    </div>
  </div>

let findUser = (userId, users) => userId->Belt.Option.map(userId => users |> User.findById(userId))

module MarkPostAsSolutionQuery = %graphql(
  `
  mutation MarkAsSolutionMutation($id: ID!) {
    markPostAsSolution(id: $id)  {
      success
    }
  }
`
)

module ArchivePostQuery = %graphql(
  `
  mutation ArchivePostMutation($id: ID!) {
    archivePost(id: $id)  {
      success
    }
  }
`
)

let markPostAsSolution = (postId, markPostAsSolutionCB) =>
  MarkPostAsSolutionQuery.make(~id=postId, ())
  |> GraphqlQuery.sendQuery
  |> Js.Promise.then_(response => {
    response["markPostAsSolution"]["success"] ? markPostAsSolutionCB() : ()
    Js.Promise.resolve()
  })
  |> ignore

let archivePost = (isFirstPost, postId, archivePostCB) =>
  Webapi.Dom.window |> Webapi.Dom.Window.confirm(
    (
      isFirstPost
        ? "Are you sure you want to delete the topic? "
        : "Are you sure you want to delete the post? "
    ) ++ "This cannot be undone.",
  )
    ? ArchivePostQuery.make(~id=postId, ())
      |> GraphqlQuery.sendQuery
      |> Js.Promise.then_(response => {
        response["archivePost"]["success"] ? archivePostCB() : ()
        Js.Promise.resolve()
      })
      |> ignore
    : ()

let optionsDropdown = (
  post,
  isPostCreator,
  isTopicCreator,
  moderator,
  isFirstPost,
  replies,
  toggleShowPostEdit,
  markPostAsSolutionCB,
  archivePostCB,
) => {
  let selected =
    <div
      ariaLabel={"Options for post " ++ Post.id(post)}
      className="flex items-center justify-center w-8 h-8 rounded leading-tight border bg-gray-100 text-gray-800 cursor-pointer hover:bg-gray-200">
      <PfIcon className="if i-ellipsis-h-regular text-base" />
    </div>
  let postTypeString = isFirstPost ? "Post" : "Reply"
  let editPostButton =
    <button
      onClick={_ => toggleShowPostEdit(_ => true)}
      className="flex w-full px-3 py-2 font-semibold items-center text-gray-700 whitespace-no-wrap">
      <FaIcon classes="fas fa-edit fa-fw text-base" />
      <span className="ml-2"> {"Edit " ++ postTypeString |> str} </span>
    </button>
  let markAsSolutionButton =
    isFirstPost || Post.solution(post)
      ? React.null
      : <button
          onClick={_ => markPostAsSolution(post |> Post.id, markPostAsSolutionCB)}
          className="flex w-full px-3 py-2 font-semibold items-center text-gray-700 whitespace-no-wrap">
          <PfIcon className="if i-check-circle-alt-regular if-fw text-base" />
          <span className="ml-2"> {"Mark as solution" |> str} </span>
        </button>
  let showDelete = isFirstPost
    ? moderator || (isPostCreator && replies |> ArrayUtils.isEmpty)
    : moderator || isPostCreator
  let deletePostButton = showDelete
    ? <button
        onClick={_ => archivePost(isFirstPost, post |> Post.id, archivePostCB)}
        className="flex w-full px-3 py-2 font-semibold items-center text-gray-700 whitespace-no-wrap">
        <FaIcon classes="fas fa-trash-alt fa-fw text-base" />
        <span className="ml-2"> {"Delete " ++ postTypeString |> str} </span>
      </button>
    : React.null
  let historyButton = switch post |> Post.editorId {
  | Some(_id) =>
    <a
      href={"/posts/" ++ (Post.id(post) ++ "/versions")}
      className="flex w-full px-3 py-2 font-semibold items-center text-gray-700 whitespace-no-wrap">
      <FaIcon classes="fas fa-history fa-fw text-base" />
      <span className="ml-2"> {"History" |> str} </span>
    </a>
  | None => React.null
  }

  let contents = switch (moderator, isTopicCreator, isPostCreator) {
  | (true, _, _) => [editPostButton, markAsSolutionButton, historyButton, deletePostButton]
  | (false, true, false) => [markAsSolutionButton, historyButton]
  | (false, true, true) => [editPostButton, markAsSolutionButton, historyButton, deletePostButton]
  | (false, false, true) => [editPostButton, historyButton, deletePostButton]
  | _ => []
  }
  <Dropdown selected contents right=true />
}

let onBorderAnimationEnd = event => {
  let element = ReactEvent.Animation.target(event) |> DomUtils.EventTarget.unsafeToElement
  element->Webapi.Dom.Element.setClassName("")
}

let navigateToEditor = () => {
  let elementId = "add-reply-to-topic"
  let element = Webapi.Dom.document |> Webapi.Dom.Document.getElementById(elementId)
  Js.Global.setTimeout(() =>
    switch element {
    | Some(e) =>
      {
        Webapi.Dom.Element.scrollIntoView(e)
        e->Webapi.Dom.Element.setClassName("w-full flex flex-col topics-show__highlighted-item")
      } |> ignore
    | None => Rollbar.error("Could not find the post to scroll to.")
    }
  , 50) |> ignore
}

@react.component
let make = (
  ~post,
  ~topic,
  ~users,
  ~posts,
  ~currentUserId,
  ~moderator,
  ~isTopicCreator,
  ~updatePostCB,
  ~addNewReplyCB,
  ~addPostLikeCB,
  ~removePostLikeCB,
  ~markPostAsSolutionCB,
  ~archivePostCB,
) => {
  let creator = Post.creatorId(post)->findUser(users)
  let editor = Post.editorId(post)->findUser(users)
  let isPostCreator =
    Post.creatorId(post)->Belt.Option.mapWithDefault(false, creatorId => currentUserId == creatorId)
  let isFirstPost = Post.postNumber(post) == 1
  let repliesToPost = isFirstPost ? [] : post |> Post.repliesToPost(posts)
  let (showPostEdit, toggleShowPostEdit) = React.useState(() => false)
  let (showReplies, toggleShowReplies) = React.useState(() => false)

  <div id={"post-show-" ++ Post.id(post)} onAnimationEnd=onBorderAnimationEnd>
    <div className="flex pt-4" key={post |> Post.id}>
      <div className="hidden lg:flex flex-col md:mt-2">
        {post |> Post.solution ? solutionIcon : React.null}
        <div className="hidden md:flex md:flex-col items-center text-center md:w-14 pr-3 md:pr-4">
          <label
            htmlFor="remember_me"
            className="bg-gray-100 flex items-center text-center rounded-full p-2 md:p-3 hover:bg-gray-200">
            <input
              id="remember_me"
              name="remember_me"
              type_="checkbox"
              className="input-checkbox h-5 w-5 bg-white text-green-600 border border-gray-500 hover:border-primary-400 rounded-md active:outline-none"
            />
          </label>
          <label
            htmlFor="remember_me"
            className="ml-1 md:ml-0 md:mt-1 leading-tight text-xs md:text-tiny font-semibold block text-gray-900">
            {"Mark as solution" |> str}
          </label>
        </div>
        <TopicsShow__LikeManager post addPostLikeCB removePostLikeCB />
      </div>
      <div className="flex-1 pb-6 lg:pb-8 topics-post-show__post-body min-w-0">
        <div className="pt-2" id="body">
          <div className="flex justify-between lg:hidden">
            <TopicsShow__UserShow user=creator createdAt={post |> Post.createdAt} />
            <div className="flex-shrink-0 mt-1">
              {isPostCreator || (moderator || isTopicCreator)
                ? optionsDropdown(
                    post,
                    isPostCreator,
                    isTopicCreator,
                    moderator,
                    isFirstPost,
                    posts,
                    toggleShowPostEdit,
                    markPostAsSolutionCB,
                    archivePostCB,
                  )
                : React.null}
            </div>
          </div>
          {showPostEdit
            ? <div className="flex-1">
                <TopicsShow__PostEditor
                  editing=true
                  id={"edit-post-" ++ Post.id(post)}
                  topic
                  currentUserId
                  post
                  replies=posts
                  users
                  handlePostCB=updatePostCB
                  handleCloseCB={() => toggleShowPostEdit(_ => false)}
                />
              </div>
            : <div className="flex items-start justify-between min-w-0">
                <div className="text-sm min-w-0">
                  <MarkdownBlock
                    markdown={post |> Post.body}
                    className="leading-normal text-sm "
                    profile=Markdown.QuestionAndAnswer
                  />
                  {switch Post.editedAt(post) {
                  | Some(editedAt) =>
                    <div>
                      <div
                        className="mt-1 inline-block px-2 py-1 rounded bg-gray-100 text-xs text-gray-800 ">
                        <span> {"Last edited by " |> str} </span>
                        <span className="font-semibold">
                          {switch editor {
                          | Some(user) => user |> User.name
                          | None => "Deleted User"
                          } |> str}
                        </span>
                        <span>
                          {" on " ++ editedAt->DateFns.format("do MMMM, yyyy HH:mm") |> str}
                        </span>
                      </div>
                    </div>
                  | None => React.null
                  }}
                </div>
                <div className="hidden lg:block flex-shrink-0 ml-3">
                  {isPostCreator || (moderator || isTopicCreator)
                    ? optionsDropdown(
                        post,
                        isPostCreator,
                        isTopicCreator,
                        moderator,
                        isFirstPost,
                        posts,
                        toggleShowPostEdit,
                        markPostAsSolutionCB,
                        archivePostCB,
                      )
                    : React.null}
                </div>
              </div>}
        </div>
        <div className="flex justify-between lg:items-end pt-4">
          <div className="flex-1 lg:flex-initial mr-3">
            <div className="hidden lg:block">
              <TopicsShow__UserShow user=creator createdAt={post |> Post.createdAt} />
            </div>
            // Showing Like, replies and solution for mobile
            <div className="flex items-center lg:items-start justify-between lg:hidden">
              <div className="flex">
                <div className="flex">
                  <TopicsShow__LikeManager post addPostLikeCB removePostLikeCB />
                  <div>
                    {repliesToPost |> ArrayUtils.isNotEmpty
                      ? <button
                          onClick={_ => toggleShowReplies(showReplies => !showReplies)}
                          className="cursor-pointer flex flex-col items-center justify-center">
                          <span
                            className="flex items-center justify-center rounded-lg lg:bg-gray-100 hover:bg-gray-300 text-gray-700 hover:text-gray-900 h-8 w-8 md:h-10 md:w-10 p-1 md:p-2 mx-auto">
                            <FaIcon classes="far fa-comment-alt" />
                          </span>
                          <span className="text-tiny lg:text-xs font-semibold">
                            {post |> Post.replies |> Array.length |> string_of_int |> str}
                          </span>
                        </button>
                      : React.null}
                  </div>
                </div>
                <div
                  className="flex md:hidden items-center bg-gray-100 px-2 md:px-3 rounded-md ml-2">
                  <input
                    id="remember_me"
                    name="remember_me"
                    type_="checkbox"
                    className="input-checkbox h-5 w-5 flex-shrink-0 bg-white text-green-600 border border-gray-500 hover:border-primary-400 rounded-md active:outline-none"
                  />
                  <label
                    htmlFor="remember_me"
                    className="ml-2 md:ml-0 md:mt-1 leading-tight cursor-pointer text-xs md:text-tiny font-semibold block text-gray-900">
                    {"Mark as solution" |> str}
                  </label>
                </div>
              </div>
              {post |> Post.solution ? solutionIcon : React.null}
            </div>
          </div>
          <div className="flex items-center text-sm font-semibold lg:mb-1">
            <button
              className="flex items-center px-3 py-2 bg-green-200 text-green-900 border border-transparent rounded mr-3 text-left focus:border-primary-400 hover:border-green-500 hover:bg-green-300">
              <PfIcon className="if i-arrow-down-circle-regular text-sm lg:text-base" />
              <div className="text-xs font-semibold pl-2"> {"Go to solution" |> str} </div>
            </button>
            <div className="hidden lg:block">
              {repliesToPost |> ArrayUtils.isNotEmpty
                ? <button
                    id={"show-replies-" ++ Post.id(post)}
                    ariaLabel={"Show replies of post " ++ Post.id(post)}
                    onClick={_ => toggleShowReplies(showReplies => !showReplies)}
                    className="border bg-white mr-3 p-2 rounded text-xs font-semibold focus:border-primary-400 hover:bg-gray-100">
                    {Inflector.pluralize(
                      "Reply",
                      ~count=post |> Post.replies |> Array.length,
                      ~inclusive=true,
                      (),
                    ) |> str}
                    <FaIcon classes={"ml-2 fas fa-chevron-" ++ (showReplies ? "up" : "down")} />
                  </button>
                : React.null}
            </div>
            <button
              onClick={_ => {
                addNewReplyCB()
                navigateToEditor()
              }}
              id={"reply-button-" ++ Post.id(post)}
              ariaLabel={isFirstPost ? "Add reply to topic" : "Add reply to post " ++ Post.id(post)}
              className="bg-gray-100 lg:border lg:bg-gray-200 p-2 rounded text-xs font-semibold focus:border-primary-400 hover:bg-gray-300">
              <FaIcon classes="fas fa-reply mr-2" /> {"Reply" |> str}
            </button>
          </div>
        </div>
        {showReplies
          ? <div
              ariaLabel={"Replies to post " ++ Post.id(post)}
              className="lg:pl-10 pt-2 topics-post-show__replies-container">
              {repliesToPost
              |> Array.map(post => <TopicsShow__PostReply key={post |> Post.id} post users />)
              |> React.array}
            </div>
          : React.null}
      </div>
    </div>
  </div>
}
